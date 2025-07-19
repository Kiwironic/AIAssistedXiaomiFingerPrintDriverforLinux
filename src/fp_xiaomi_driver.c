/**
 * @file fp_xiaomi_driver.c
 * @brief Xiaomi FPC Fingerprint Scanner Linux Driver
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * Linux kernel driver for FPC Fingerprint Reader (Disum) in Xiaomi laptops
 * Based on fingerprint-ocv project with Xiaomi-specific optimizations
 * 
 * Hardware: FPC Sensor Controller L:0001 (VID:PID 10A5:9201)
 * Target: Xiaomi Book Pro 14 2022 and compatible models
 * 
 * @copyright GPL v2 License
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/usb.h>
#include <linux/slab.h>
#include <linux/mutex.h>
#include <linux/workqueue.h>
#include <linux/firmware.h>
#include <linux/delay.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/poll.h>
#include <linux/wait.h>
#include <linux/atomic.h>
#include <linux/kref.h>
#include <linux/pm_runtime.h>

#include "fp_xiaomi_driver.h"

/* Module Information */
MODULE_AUTHOR("AI-Assisted Development");
MODULE_DESCRIPTION("Xiaomi FPC Fingerprint Scanner Driver");
MODULE_LICENSE("GPL v2");
MODULE_VERSION("1.0.0");

/* Device identification */
#define FPC_VENDOR_ID    0x10A5
#define FPC_PRODUCT_ID   0x9201
#define FPC_DEVICE_NAME  "FPC Fingerprint Reader (Xiaomi)"

/* Driver constants */
#define FP_XIAOMI_MINOR_BASE    0
#define FP_XIAOMI_MAX_DEVICES   8
#define FP_XIAOMI_BUFFER_SIZE   4096
#define FP_XIAOMI_TIMEOUT_MS    5000
#define FP_XIAOMI_RETRY_COUNT   3

/* USB endpoints */
#define FP_BULK_IN_EP     0x81
#define FP_BULK_OUT_EP    0x02
#define FP_INT_IN_EP      0x83

/* Device states */
enum fp_device_state {
    FP_STATE_DISCONNECTED = 0,
    FP_STATE_INITIALIZING,
    FP_STATE_READY,
    FP_STATE_CAPTURING,
    FP_STATE_PROCESSING,
    FP_STATE_ERROR,
    FP_STATE_SUSPENDED
};

/* Error codes */
enum fp_error_codes {
    FP_SUCCESS = 0,
    FP_ERROR_DEVICE = -1,
    FP_ERROR_PROTOCOL = -2,
    FP_ERROR_TIMEOUT = -3,
    FP_ERROR_NO_FINGER = -4,
    FP_ERROR_BAD_IMAGE = -5,
    FP_ERROR_NO_MATCH = -6,
    FP_ERROR_HARDWARE = -7,
    FP_ERROR_FIRMWARE = -8,
    FP_ERROR_BUSY = -9,
    FP_ERROR_MEMORY = -10
};

/* Device structure */
struct fp_xiaomi_device {
    struct usb_device *udev;
    struct usb_interface *interface;
    struct kref kref;
    
    /* USB endpoints */
    struct usb_endpoint_descriptor *bulk_in;
    struct usb_endpoint_descriptor *bulk_out;
    struct usb_endpoint_descriptor *int_in;
    
    /* Device state and synchronization */
    enum fp_device_state state;
    struct mutex device_lock;
    struct mutex io_lock;
    spinlock_t state_lock;
    
    /* Character device interface */
    struct cdev cdev;
    struct device *dev;
    int minor;
    
    /* I/O buffers and URBs */
    unsigned char *bulk_in_buffer;
    unsigned char *bulk_out_buffer;
    unsigned char *int_in_buffer;
    struct urb *bulk_in_urb;
    struct urb *bulk_out_urb;
    struct urb *int_in_urb;
    
    /* Work queue for async operations */
    struct workqueue_struct *workqueue;
    struct work_struct init_work;
    struct work_struct error_work;
    
    /* Wait queues for blocking operations */
    wait_queue_head_t read_wait;
    wait_queue_head_t write_wait;
    
    /* Statistics and debugging */
    atomic_t open_count;
    atomic_t error_count;
    atomic_t retry_count;
    unsigned long last_activity;
    
    /* Power management */
    struct pm_qos_request pm_qos;
    bool pm_suspended;
    
    /* Firmware information */
    char firmware_version[32];
    bool firmware_loaded;
    
    /* Device capabilities */
    u16 image_width;
    u16 image_height;
    u8 template_count;
    u32 device_flags;
};

/* Global variables */
static struct class *fp_xiaomi_class;
static dev_t fp_xiaomi_devt;
static DEFINE_IDR(fp_xiaomi_idr);
static DEFINE_MUTEX(fp_xiaomi_mutex);

/* USB device table */
static const struct usb_device_id fp_xiaomi_table[] = {
    { USB_DEVICE(FPC_VENDOR_ID, FPC_PRODUCT_ID) },
    { }
};
MODULE_DEVICE_TABLE(usb, fp_xiaomi_table);

/* Function prototypes */
static int fp_xiaomi_probe(struct usb_interface *interface,
                          const struct usb_device_id *id);
static void fp_xiaomi_disconnect(struct usb_interface *interface);
static int fp_xiaomi_suspend(struct usb_interface *interface, pm_message_t message);
static int fp_xiaomi_resume(struct usb_interface *interface);
static int fp_xiaomi_pre_reset(struct usb_interface *interface);
static int fp_xiaomi_post_reset(struct usb_interface *interface);

/* USB driver structure */
static struct usb_driver fp_xiaomi_driver = {
    .name = "fp_xiaomi",
    .probe = fp_xiaomi_probe,
    .disconnect = fp_xiaomi_disconnect,
    .suspend = fp_xiaomi_suspend,
    .resume = fp_xiaomi_resume,
    .pre_reset = fp_xiaomi_pre_reset,
    .post_reset = fp_xiaomi_post_reset,
    .id_table = fp_xiaomi_table,
    .supports_autosuspend = 1,
};

/**
 * Logging macros with different levels
 */
#define fp_dev_err(dev, fmt, args...) \
    dev_err(&(dev)->udev->dev, "[FP_XIAOMI] ERROR: " fmt, ##args)

#define fp_dev_warn(dev, fmt, args...) \
    dev_warn(&(dev)->udev->dev, "[FP_XIAOMI] WARN: " fmt, ##args)

#define fp_dev_info(dev, fmt, args...) \
    dev_info(&(dev)->udev->dev, "[FP_XIAOMI] INFO: " fmt, ##args)

#define fp_dev_dbg(dev, fmt, args...) \
    dev_dbg(&(dev)->udev->dev, "[FP_XIAOMI] DEBUG: " fmt, ##args)

/**
 * Device reference counting
 */
static void fp_xiaomi_delete(struct kref *kref)
{
    struct fp_xiaomi_device *dev = container_of(kref, struct fp_xiaomi_device, kref);
    
    fp_dev_dbg(dev, "Deleting device structure");
    
    /* Clean up USB resources */
    usb_free_urb(dev->bulk_in_urb);
    usb_free_urb(dev->bulk_out_urb);
    usb_free_urb(dev->int_in_urb);
    
    kfree(dev->bulk_in_buffer);
    kfree(dev->bulk_out_buffer);
    kfree(dev->int_in_buffer);
    
    /* Clean up work queue */
    if (dev->workqueue) {
        destroy_workqueue(dev->workqueue);
    }
    
    /* Clean up power management */
    pm_qos_remove_request(&dev->pm_qos);
    
    usb_put_dev(dev->udev);
    kfree(dev);
}

static inline void fp_xiaomi_get_device(struct fp_xiaomi_device *dev)
{
    kref_get(&dev->kref);
}

static inline void fp_xiaomi_put_device(struct fp_xiaomi_device *dev)
{
    kref_put(&dev->kref, fp_xiaomi_delete);
}

/**
 * State management with proper locking
 */
static void fp_xiaomi_set_state(struct fp_xiaomi_device *dev, enum fp_device_state new_state)
{
    unsigned long flags;
    enum fp_device_state old_state;
    
    spin_lock_irqsave(&dev->state_lock, flags);
    old_state = dev->state;
    dev->state = new_state;
    dev->last_activity = jiffies;
    spin_unlock_irqrestore(&dev->state_lock, flags);
    
    fp_dev_dbg(dev, "State transition: %d -> %d", old_state, new_state);
    
    /* Wake up waiting processes */
    wake_up_interruptible(&dev->read_wait);
    wake_up_interruptible(&dev->write_wait);
}

static enum fp_device_state fp_xiaomi_get_state(struct fp_xiaomi_device *dev)
{
    unsigned long flags;
    enum fp_device_state state;
    
    spin_lock_irqsave(&dev->state_lock, flags);
    state = dev->state;
    spin_unlock_irqrestore(&dev->state_lock, flags);
    
    return state;
}

/**
 * USB communication functions
 */
static int fp_xiaomi_bulk_transfer(struct fp_xiaomi_device *dev,
                                  unsigned char *buffer, int length,
                                  int endpoint, bool is_write)
{
    int ret;
    int actual_length;
    unsigned int pipe;
    
    if (!dev || !buffer || length <= 0) {
        return -EINVAL;
    }
    
    if (fp_xiaomi_get_state(dev) == FP_STATE_DISCONNECTED) {
        return -ENODEV;
    }
    
    /* Create appropriate pipe */
    if (is_write) {
        pipe = usb_sndbulkpipe(dev->udev, endpoint);
    } else {
        pipe = usb_rcvbulkpipe(dev->udev, endpoint);
    }
    
    fp_dev_dbg(dev, "Bulk transfer: %s %d bytes on endpoint 0x%02x",
               is_write ? "write" : "read", length, endpoint);
    
    /* Perform synchronous bulk transfer with timeout */
    ret = usb_bulk_msg(dev->udev, pipe, buffer, length,
                       &actual_length, FP_XIAOMI_TIMEOUT_MS);
    
    if (ret < 0) {
        fp_dev_err(dev, "Bulk transfer failed: %d", ret);
        atomic_inc(&dev->error_count);
        
        /* Handle specific error conditions */
        switch (ret) {
        case -ETIMEDOUT:
            fp_dev_warn(dev, "Transfer timeout");
            break;
        case -ENODEV:
            fp_xiaomi_set_state(dev, FP_STATE_DISCONNECTED);
            break;
        case -EPIPE:
            fp_dev_warn(dev, "Endpoint stalled, clearing");
            usb_clear_halt(dev->udev, pipe);
            break;
        }
        
        return ret;
    }
    
    if (actual_length != length && is_write) {
        fp_dev_warn(dev, "Partial write: %d/%d bytes", actual_length, length);
        return -EIO;
    }
    
    fp_dev_dbg(dev, "Transfer completed: %d bytes", actual_length);
    return actual_length;
}

/**
 * Device initialization and firmware loading
 */
static int fp_xiaomi_load_firmware(struct fp_xiaomi_device *dev)
{
    const struct firmware *fw;
    int ret;
    char fw_name[64];
    
    /* Try different firmware names based on device */
    snprintf(fw_name, sizeof(fw_name), "fpc_xiaomi_%04x_%04x.bin",
             FPC_VENDOR_ID, FPC_PRODUCT_ID);
    
    fp_dev_info(dev, "Loading firmware: %s", fw_name);
    
    ret = request_firmware(&fw, fw_name, &dev->udev->dev);
    if (ret < 0) {
        /* Try generic firmware */
        ret = request_firmware(&fw, "fpc_xiaomi_generic.bin", &dev->udev->dev);
        if (ret < 0) {
            fp_dev_warn(dev, "No firmware found, using device defaults");
            dev->firmware_loaded = false;
            return 0; /* Not fatal */
        }
    }
    
    fp_dev_info(dev, "Firmware loaded: %zu bytes", fw->size);
    
    /* TODO: Implement firmware upload protocol */
    /* This would involve sending firmware data to device */
    
    release_firmware(fw);
    dev->firmware_loaded = true;
    
    return 0;
}

static int fp_xiaomi_get_device_info(struct fp_xiaomi_device *dev)
{
    unsigned char cmd_buffer[16];
    unsigned char resp_buffer[64];
    int ret;
    
    fp_dev_dbg(dev, "Getting device information");
    
    /* Prepare device info command */
    memset(cmd_buffer, 0, sizeof(cmd_buffer));
    cmd_buffer[0] = 0x01; /* Get device info command */
    
    /* Send command */
    ret = fp_xiaomi_bulk_transfer(dev, cmd_buffer, 16, FP_BULK_OUT_EP, true);
    if (ret < 0) {
        fp_dev_err(dev, "Failed to send device info command: %d", ret);
        return ret;
    }
    
    /* Receive response */
    ret = fp_xiaomi_bulk_transfer(dev, resp_buffer, sizeof(resp_buffer), 
                                 FP_BULK_IN_EP, false);
    if (ret < 0) {
        fp_dev_err(dev, "Failed to receive device info: %d", ret);
        return ret;
    }
    
    /* Parse response */
    if (ret >= 32) {
        snprintf(dev->firmware_version, sizeof(dev->firmware_version),
                "%d.%d.%d.%d", resp_buffer[8], resp_buffer[9], 
                resp_buffer[10], resp_buffer[11]);
        
        dev->image_width = (resp_buffer[16] << 8) | resp_buffer[17];
        dev->image_height = (resp_buffer[18] << 8) | resp_buffer[19];
        dev->template_count = resp_buffer[20];
        dev->device_flags = (resp_buffer[24] << 24) | (resp_buffer[25] << 16) |
                           (resp_buffer[26] << 8) | resp_buffer[27];
        
        fp_dev_info(dev, "Device info: FW %s, Image %dx%d, Templates %d",
                   dev->firmware_version, dev->image_width, 
                   dev->image_height, dev->template_count);
    }
    
    return 0;
}

/**
 * Device initialization work function
 */
static void fp_xiaomi_init_work(struct work_struct *work)
{
    struct fp_xiaomi_device *dev = container_of(work, struct fp_xiaomi_device, init_work);
    int ret;
    int retry_count = 0;
    
    fp_dev_info(dev, "Starting device initialization");
    fp_xiaomi_set_state(dev, FP_STATE_INITIALIZING);
    
    /* Retry initialization if it fails */
    while (retry_count < FP_XIAOMI_RETRY_COUNT) {
        /* Load firmware if available */
        ret = fp_xiaomi_load_firmware(dev);
        if (ret < 0) {
            fp_dev_err(dev, "Firmware loading failed: %d", ret);
            goto retry;
        }
        
        /* Get device information */
        ret = fp_xiaomi_get_device_info(dev);
        if (ret < 0) {
            fp_dev_err(dev, "Device info retrieval failed: %d", ret);
            goto retry;
        }
        
        /* Device initialized successfully */
        fp_xiaomi_set_state(dev, FP_STATE_READY);
        fp_dev_info(dev, "Device initialization completed");
        return;
        
retry:
        retry_count++;
        atomic_inc(&dev->retry_count);
        fp_dev_warn(dev, "Initialization retry %d/%d", retry_count, FP_XIAOMI_RETRY_COUNT);
        msleep(1000); /* Wait before retry */
    }
    
    /* All retries failed */
    fp_dev_err(dev, "Device initialization failed after %d retries", FP_XIAOMI_RETRY_COUNT);
    fp_xiaomi_set_state(dev, FP_STATE_ERROR);
}

/**
 * Error handling work function
 */
static void fp_xiaomi_error_work(struct work_struct *work)
{
    struct fp_xiaomi_device *dev = container_of(work, struct fp_xiaomi_device, error_work);
    
    fp_dev_info(dev, "Handling device error, attempting recovery");
    
    /* Try to reset and reinitialize the device */
    if (fp_xiaomi_get_state(dev) != FP_STATE_DISCONNECTED) {
        /* Schedule reinitialization */
        queue_work(dev->workqueue, &dev->init_work);
    }
}

/**
 * Character device file operations
 */
static int fp_xiaomi_open(struct inode *inode, struct file *file)
{
    struct fp_xiaomi_device *dev;
    int ret = 0;
    
    dev = container_of(inode->i_cdev, struct fp_xiaomi_device, cdev);
    
    /* Check if device is still connected */
    if (fp_xiaomi_get_state(dev) == FP_STATE_DISCONNECTED) {
        return -ENODEV;
    }
    
    /* Increment reference count */
    fp_xiaomi_get_device(dev);
    
    /* Store device pointer in file private data */
    file->private_data = dev;
    
    /* Increment open count */
    atomic_inc(&dev->open_count);
    
    fp_dev_info(dev, "Device opened (open count: %d)", 
               atomic_read(&dev->open_count));
    
    return ret;
}

static int fp_xiaomi_release(struct inode *inode, struct file *file)
{
    struct fp_xiaomi_device *dev = file->private_data;
    
    if (dev) {
        atomic_dec(&dev->open_count);
        fp_dev_info(dev, "Device closed (open count: %d)", 
                   atomic_read(&dev->open_count));
        
        /* Release device reference */
        fp_xiaomi_put_device(dev);
    }
    
    return 0;
}

static ssize_t fp_xiaomi_read(struct file *file, char __user *buffer,
                             size_t count, loff_t *ppos)
{
    struct fp_xiaomi_device *dev = file->private_data;
    int ret;
    
    if (!dev || count == 0) {
        return -EINVAL;
    }
    
    if (count > FP_XIAOMI_BUFFER_SIZE) {
        count = FP_XIAOMI_BUFFER_SIZE;
    }
    
    /* Check device state */
    if (fp_xiaomi_get_state(dev) != FP_STATE_READY) {
        return -ENODEV;
    }
    
    mutex_lock(&dev->io_lock);
    
    /* Read data from device */
    ret = fp_xiaomi_bulk_transfer(dev, dev->bulk_in_buffer, count,
                                 FP_BULK_IN_EP, false);
    if (ret < 0) {
        goto out;
    }
    
    /* Copy to user space */
    if (copy_to_user(buffer, dev->bulk_in_buffer, ret)) {
        ret = -EFAULT;
        goto out;
    }
    
out:
    mutex_unlock(&dev->io_lock);
    return ret;
}

static ssize_t fp_xiaomi_write(struct file *file, const char __user *buffer,
                              size_t count, loff_t *ppos)
{
    struct fp_xiaomi_device *dev = file->private_data;
    int ret;
    
    if (!dev || count == 0) {
        return -EINVAL;
    }
    
    if (count > FP_XIAOMI_BUFFER_SIZE) {
        count = FP_XIAOMI_BUFFER_SIZE;
    }
    
    /* Check device state */
    if (fp_xiaomi_get_state(dev) != FP_STATE_READY) {
        return -ENODEV;
    }
    
    mutex_lock(&dev->io_lock);
    
    /* Copy from user space */
    if (copy_from_user(dev->bulk_out_buffer, buffer, count)) {
        ret = -EFAULT;
        goto out;
    }
    
    /* Write data to device */
    ret = fp_xiaomi_bulk_transfer(dev, dev->bulk_out_buffer, count,
                                 FP_BULK_OUT_EP, true);
    
out:
    mutex_unlock(&dev->io_lock);
    return ret;
}

static __poll_t fp_xiaomi_poll(struct file *file, poll_table *wait)
{
    struct fp_xiaomi_device *dev = file->private_data;
    __poll_t mask = 0;
    
    if (!dev) {
        return EPOLLERR;
    }
    
    poll_wait(file, &dev->read_wait, wait);
    poll_wait(file, &dev->write_wait, wait);
    
    /* Check if device is ready for I/O */
    if (fp_xiaomi_get_state(dev) == FP_STATE_READY) {
        mask |= EPOLLIN | EPOLLRDNORM;  /* Ready for reading */
        mask |= EPOLLOUT | EPOLLWRNORM; /* Ready for writing */
    } else if (fp_xiaomi_get_state(dev) == FP_STATE_DISCONNECTED) {
        mask |= EPOLLERR | EPOLLHUP;
    }
    
    return mask;
}

/* Character device file operations */
static const struct file_operations fp_xiaomi_fops = {
    .owner = THIS_MODULE,
    .open = fp_xiaomi_open,
    .release = fp_xiaomi_release,
    .read = fp_xiaomi_read,
    .write = fp_xiaomi_write,
    .poll = fp_xiaomi_poll,
    .llseek = no_llseek,
};

/**
 * USB probe function - called when device is connected
 */
static int fp_xiaomi_probe(struct usb_interface *interface,
                          const struct usb_device_id *id)
{
    struct fp_xiaomi_device *dev;
    struct usb_device *udev = interface_to_usbdev(interface);
    struct usb_host_interface *iface_desc;
    struct usb_endpoint_descriptor *endpoint;
    int ret = 0;
    int i;
    
    dev_info(&interface->dev, "[FP_XIAOMI] Probing device %04x:%04x",
             id->idVendor, id->idProduct);
    
    /* Allocate device structure */
    dev = kzalloc(sizeof(*dev), GFP_KERNEL);
    if (!dev) {
        return -ENOMEM;
    }
    
    /* Initialize device structure */
    kref_init(&dev->kref);
    dev->udev = usb_get_dev(udev);
    dev->interface = interface;
    
    /* Initialize synchronization primitives */
    mutex_init(&dev->device_lock);
    mutex_init(&dev->io_lock);
    spin_lock_init(&dev->state_lock);
    init_waitqueue_head(&dev->read_wait);
    init_waitqueue_head(&dev->write_wait);
    
    /* Initialize atomic counters */
    atomic_set(&dev->open_count, 0);
    atomic_set(&dev->error_count, 0);
    atomic_set(&dev->retry_count, 0);
    
    /* Set initial state */
    fp_xiaomi_set_state(dev, FP_STATE_DISCONNECTED);
    
    /* Parse USB interface */
    iface_desc = interface->cur_altsetting;
    
    for (i = 0; i < iface_desc->desc.bNumEndpoints; i++) {
        endpoint = &iface_desc->endpoint[i].desc;
        
        if (usb_endpoint_is_bulk_in(endpoint)) {
            dev->bulk_in = endpoint;
            fp_dev_dbg(dev, "Found bulk IN endpoint: 0x%02x", 
                      endpoint->bEndpointAddress);
        } else if (usb_endpoint_is_bulk_out(endpoint)) {
            dev->bulk_out = endpoint;
            fp_dev_dbg(dev, "Found bulk OUT endpoint: 0x%02x", 
                      endpoint->bEndpointAddress);
        } else if (usb_endpoint_is_int_in(endpoint)) {
            dev->int_in = endpoint;
            fp_dev_dbg(dev, "Found interrupt IN endpoint: 0x%02x", 
                      endpoint->bEndpointAddress);
        }
    }
    
    /* Verify required endpoints */
    if (!dev->bulk_in || !dev->bulk_out) {
        fp_dev_err(dev, "Required endpoints not found");
        ret = -ENODEV;
        goto error;
    }
    
    /* Allocate I/O buffers */
    dev->bulk_in_buffer = kzalloc(FP_XIAOMI_BUFFER_SIZE, GFP_KERNEL);
    dev->bulk_out_buffer = kzalloc(FP_XIAOMI_BUFFER_SIZE, GFP_KERNEL);
    dev->int_in_buffer = kzalloc(64, GFP_KERNEL);
    
    if (!dev->bulk_in_buffer || !dev->bulk_out_buffer || !dev->int_in_buffer) {
        ret = -ENOMEM;
        goto error;
    }
    
    /* Allocate URBs */
    dev->bulk_in_urb = usb_alloc_urb(0, GFP_KERNEL);
    dev->bulk_out_urb = usb_alloc_urb(0, GFP_KERNEL);
    dev->int_in_urb = usb_alloc_urb(0, GFP_KERNEL);
    
    if (!dev->bulk_in_urb || !dev->bulk_out_urb || !dev->int_in_urb) {
        ret = -ENOMEM;
        goto error;
    }
    
    /* Create work queue */
    dev->workqueue = create_singlethread_workqueue("fp_xiaomi_wq");
    if (!dev->workqueue) {
        ret = -ENOMEM;
        goto error;
    }
    
    /* Initialize work items */
    INIT_WORK(&dev->init_work, fp_xiaomi_init_work);
    INIT_WORK(&dev->error_work, fp_xiaomi_error_work);
    
    /* Set up power management */
    pm_qos_add_request(&dev->pm_qos, PM_QOS_CPU_DMA_LATENCY, 
                       PM_QOS_DEFAULT_VALUE);
    
    /* Get minor number */
    mutex_lock(&fp_xiaomi_mutex);
    ret = idr_alloc(&fp_xiaomi_idr, dev, 0, FP_XIAOMI_MAX_DEVICES, GFP_KERNEL);
    if (ret < 0) {
        mutex_unlock(&fp_xiaomi_mutex);
        fp_dev_err(dev, "Failed to allocate minor number: %d", ret);
        goto error;
    }
    dev->minor = ret;
    mutex_unlock(&fp_xiaomi_mutex);
    
    /* Initialize character device */
    cdev_init(&dev->cdev, &fp_xiaomi_fops);
    dev->cdev.owner = THIS_MODULE;
    
    ret = cdev_add(&dev->cdev, MKDEV(MAJOR(fp_xiaomi_devt), dev->minor), 1);
    if (ret) {
        fp_dev_err(dev, "Failed to add character device: %d", ret);
        goto error_idr;
    }
    
    /* Create device node */
    dev->dev = device_create(fp_xiaomi_class, &interface->dev,
                            MKDEV(MAJOR(fp_xiaomi_devt), dev->minor),
                            dev, "fp_xiaomi%d", dev->minor);
    if (IS_ERR(dev->dev)) {
        ret = PTR_ERR(dev->dev);
        fp_dev_err(dev, "Failed to create device node: %d", ret);
        goto error_cdev;
    }
    
    /* Store device pointer in interface */
    usb_set_intfdata(interface, dev);
    
    /* Enable autosuspend */
    usb_enable_autosuspend(udev);
    
    /* Start device initialization */
    queue_work(dev->workqueue, &dev->init_work);
    
    fp_dev_info(dev, "Device probe completed successfully (minor %d)", dev->minor);
    return 0;
    
error_cdev:
    cdev_del(&dev->cdev);
error_idr:
    mutex_lock(&fp_xiaomi_mutex);
    idr_remove(&fp_xiaomi_idr, dev->minor);
    mutex_unlock(&fp_xiaomi_mutex);
error:
    fp_xiaomi_put_device(dev);
    return ret;
}

/**
 * USB disconnect function - called when device is removed
 */
static void fp_xiaomi_disconnect(struct usb_interface *interface)
{
    struct fp_xiaomi_device *dev = usb_get_intfdata(interface);
    
    if (!dev) {
        return;
    }
    
    fp_dev_info(dev, "Device disconnecting");
    
    /* Set disconnected state */
    fp_xiaomi_set_state(dev, FP_STATE_DISCONNECTED);
    
    /* Remove device node */
    device_destroy(fp_xiaomi_class, MKDEV(MAJOR(fp_xiaomi_devt), dev->minor));
    
    /* Remove character device */
    cdev_del(&dev->cdev);
    
    /* Remove from IDR */
    mutex_lock(&fp_xiaomi_mutex);
    idr_remove(&fp_xiaomi_idr, dev->minor);
    mutex_unlock(&fp_xiaomi_mutex);
    
    /* Cancel pending work */
    cancel_work_sync(&dev->init_work);
    cancel_work_sync(&dev->error_work);
    
    /* Wake up any waiting processes */
    wake_up_interruptible(&dev->read_wait);
    wake_up_interruptible(&dev->write_wait);
    
    /* Clear interface data */
    usb_set_intfdata(interface, NULL);
    
    /* Release device reference */
    fp_xiaomi_put_device(dev);
    
    dev_info(&interface->dev, "[FP_XIAOMI] Device disconnected");
}

/**
 * Power management functions
 */
static int fp_xiaomi_suspend(struct usb_interface *interface, pm_message_t message)
{
    struct fp_xiaomi_device *dev = usb_get_intfdata(interface);
    
    if (!dev) {
        return 0;
    }
    
    fp_dev_info(dev, "Suspending device");
    
    /* Cancel pending work */
    cancel_work_sync(&dev->init_work);
    cancel_work_sync(&dev->error_work);
    
    /* Set suspended state */
    mutex_lock(&dev->device_lock);
    dev->pm_suspended = true;
    fp_xiaomi_set_state(dev, FP_STATE_SUSPENDED);
    mutex_unlock(&dev->device_lock);
    
    return 0;
}

static int fp_xiaomi_resume(struct usb_interface *interface)
{
    struct fp_xiaomi_device *dev = usb_get_intfdata(interface);
    
    if (!dev) {
        return 0;
    }
    
    fp_dev_info(dev, "Resuming device");
    
    mutex_lock(&dev->device_lock);
    dev->pm_suspended = false;
    mutex_unlock(&dev->device_lock);
    
    /* Reinitialize device */
    queue_work(dev->workqueue, &dev->init_work);
    
    return 0;
}

static int fp_xiaomi_pre_reset(struct usb_interface *interface)
{
    struct fp_xiaomi_device *dev = usb_get_intfdata(interface);
    
    if (!dev) {
        return 0;
    }
    
    fp_dev_info(dev, "Pre-reset");
    
    mutex_lock(&dev->device_lock);
    return 0; /* Keep lock held */
}

static int fp_xiaomi_post_reset(struct usb_interface *interface)
{
    struct fp_xiaomi_device *dev = usb_get_intfdata(interface);
    
    if (!dev) {
        return 0;
    }
    
    fp_dev_info(dev, "Post-reset");
    
    /* Reinitialize device */
    queue_work(dev->workqueue, &dev->init_work);
    
    mutex_unlock(&dev->device_lock);
    return 0;
}

/**
 * Module initialization and cleanup
 */
static int __init fp_xiaomi_init(void)
{
    int ret;
    
    pr_info("[FP_XIAOMI] Loading Xiaomi FPC Fingerprint Driver v1.0.0\n");
    
    /* Allocate character device numbers */
    ret = alloc_chrdev_region(&fp_xiaomi_devt, FP_XIAOMI_MINOR_BASE,
                             FP_XIAOMI_MAX_DEVICES, "fp_xiaomi");
    if (ret) {
        pr_err("[FP_XIAOMI] Failed to allocate character device region: %d\n", ret);
        return ret;
    }
    
    /* Create device class */
    fp_xiaomi_class = class_create(THIS_MODULE, "fp_xiaomi");
    if (IS_ERR(fp_xiaomi_class)) {
        ret = PTR_ERR(fp_xiaomi_class);
        pr_err("[FP_XIAOMI] Failed to create device class: %d\n", ret);
        goto error_chrdev;
    }
    
    /* Register USB driver */
    ret = usb_register(&fp_xiaomi_driver);
    if (ret) {
        pr_err("[FP_XIAOMI] Failed to register USB driver: %d\n", ret);
        goto error_class;
    }
    
    pr_info("[FP_XIAOMI] Driver loaded successfully\n");
    return 0;
    
error_class:
    class_destroy(fp_xiaomi_class);
error_chrdev:
    unregister_chrdev_region(fp_xiaomi_devt, FP_XIAOMI_MAX_DEVICES);
    return ret;
}

static void __exit fp_xiaomi_exit(void)
{
    pr_info("[FP_XIAOMI] Unloading Xiaomi FPC Fingerprint Driver\n");
    
    /* Unregister USB driver */
    usb_deregister(&fp_xiaomi_driver);
    
    /* Destroy device class */
    class_destroy(fp_xiaomi_class);
    
    /* Release character device numbers */
    unregister_chrdev_region(fp_xiaomi_devt, FP_XIAOMI_MAX_DEVICES);
    
    /* Clean up IDR */
    idr_destroy(&fp_xiaomi_idr);
    
    pr_info("[FP_XIAOMI] Driver unloaded\n");
}

module_init(fp_xiaomi_init);
module_exit(fp_xiaomi_exit);