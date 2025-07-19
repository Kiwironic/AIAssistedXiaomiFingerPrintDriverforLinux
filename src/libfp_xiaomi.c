/**
 * @file libfp_xiaomi.c
 * @brief User-space library for Xiaomi FPC Fingerprint Scanner
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * User-space library providing high-level API for the Xiaomi FPC
 * fingerprint scanner driver. This library simplifies integration
 * with applications and provides a clean C API.
 * 
 * @copyright GPL v2 License
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/time.h>
#include <pthread.h>

#include "libfp_xiaomi.h"
#include "fp_xiaomi_driver.h"

/* Library version */
#define LIBFP_XIAOMI_VERSION_MAJOR 1
#define LIBFP_XIAOMI_VERSION_MINOR 0
#define LIBFP_XIAOMI_VERSION_PATCH 0

/* Default device path */
#define DEFAULT_DEVICE_PATH "/dev/fp_xiaomi0"

/* Internal structure for device handle */
struct fp_xiaomi_device_internal {
    int fd;                          /* Device file descriptor */
    char device_path[256];           /* Device path */
    struct fp_device_info info;     /* Device information */
    pthread_mutex_t mutex;          /* Thread safety */
    bool initialized;               /* Initialization status */
    fp_xiaomi_event_callback_t event_callback; /* Event callback */
    void *callback_data;            /* Callback user data */
    pthread_t event_thread;         /* Event handling thread */
    bool event_thread_running;      /* Event thread status */
};

/* Global library initialization status */
static bool library_initialized = false;
static pthread_mutex_t library_mutex = PTHREAD_MUTEX_INITIALIZER;

/**
 * Library initialization
 */
int fp_xiaomi_init(void)
{
    pthread_mutex_lock(&library_mutex);
    
    if (library_initialized) {
        pthread_mutex_unlock(&library_mutex);
        return FP_XIAOMI_SUCCESS;
    }
    
    /* Initialize library resources */
    library_initialized = true;
    
    pthread_mutex_unlock(&library_mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Library cleanup
 */
void fp_xiaomi_cleanup(void)
{
    pthread_mutex_lock(&library_mutex);
    
    if (!library_initialized) {
        pthread_mutex_unlock(&library_mutex);
        return;
    }
    
    /* Cleanup library resources */
    library_initialized = false;
    
    pthread_mutex_unlock(&library_mutex);
}

/**
 * Get library version
 */
void fp_xiaomi_get_version(int *major, int *minor, int *patch)
{
    if (major) *major = LIBFP_XIAOMI_VERSION_MAJOR;
    if (minor) *minor = LIBFP_XIAOMI_VERSION_MINOR;
    if (patch) *patch = LIBFP_XIAOMI_VERSION_PATCH;
}

/**
 * Open device
 */
fp_xiaomi_device_t *fp_xiaomi_open_device(const char *device_path)
{
    struct fp_xiaomi_device_internal *dev;
    int ret;
    
    if (!library_initialized) {
        errno = EINVAL;
        return NULL;
    }
    
    /* Allocate device structure */
    dev = calloc(1, sizeof(*dev));
    if (!dev) {
        errno = ENOMEM;
        return NULL;
    }
    
    /* Set device path */
    if (device_path) {
        strncpy(dev->device_path, device_path, sizeof(dev->device_path) - 1);
    } else {
        strncpy(dev->device_path, DEFAULT_DEVICE_PATH, sizeof(dev->device_path) - 1);
    }
    
    /* Initialize mutex */
    if (pthread_mutex_init(&dev->mutex, NULL) != 0) {
        free(dev);
        errno = ENOMEM;
        return NULL;
    }
    
    /* Open device */
    dev->fd = open(dev->device_path, O_RDWR);
    if (dev->fd < 0) {
        pthread_mutex_destroy(&dev->mutex);
        free(dev);
        return NULL;
    }
    
    /* Get device information */
    ret = ioctl(dev->fd, FP_IOC_GET_DEVICE_INFO, &dev->info);
    if (ret < 0) {
        close(dev->fd);
        pthread_mutex_destroy(&dev->mutex);
        free(dev);
        return NULL;
    }
    
    dev->initialized = true;
    return (fp_xiaomi_device_t *)dev;
}

/**
 * Close device
 */
int fp_xiaomi_close_device(fp_xiaomi_device_t *device)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Stop event thread if running */
    if (dev->event_thread_running) {
        dev->event_thread_running = false;
        pthread_cancel(dev->event_thread);
        pthread_join(dev->event_thread, NULL);
    }
    
    /* Close device */
    if (dev->fd >= 0) {
        close(dev->fd);
        dev->fd = -1;
    }
    
    dev->initialized = false;
    
    pthread_mutex_unlock(&dev->mutex);
    pthread_mutex_destroy(&dev->mutex);
    
    free(dev);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Get device information
 */
int fp_xiaomi_get_device_info(fp_xiaomi_device_t *device, fp_xiaomi_device_info_t *info)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    
    if (!dev || !dev->initialized || !info) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Copy device information */
    info->vendor_id = dev->info.vendor_id;
    info->product_id = dev->info.product_id;
    strncpy(info->firmware_version, (char *)dev->info.firmware_version, 
            sizeof(info->firmware_version) - 1);
    info->image_width = dev->info.image_width;
    info->image_height = dev->info.image_height;
    info->template_count = dev->info.template_count;
    info->capabilities = dev->info.capabilities;
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Get device status
 */
int fp_xiaomi_get_status(fp_xiaomi_device_t *device, fp_xiaomi_status_t *status)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_device_status driver_status;
    int ret;
    
    if (!dev || !dev->initialized || !status) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    ret = ioctl(dev->fd, FP_IOC_GET_STATUS, &driver_status);
    if (ret < 0) {
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    /* Convert driver status to library status */
    status->state = driver_status.state;
    status->last_error = driver_status.last_error;
    status->uptime_ms = driver_status.uptime_ms;
    status->total_captures = driver_status.total_captures;
    status->successful_matches = driver_status.successful_matches;
    status->failed_matches = driver_status.failed_matches;
    status->error_count = driver_status.error_count;
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Capture fingerprint image
 */
int fp_xiaomi_capture_image(fp_xiaomi_device_t *device, fp_xiaomi_image_t *image)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_image_data driver_image;
    int ret;
    
    if (!dev || !dev->initialized || !image) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Allocate image buffer */
    driver_image.data = malloc(FP_XIAOMI_MAX_IMAGE_SIZE);
    if (!driver_image.data) {
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_MEMORY;
    }
    
    /* Capture image */
    ret = ioctl(dev->fd, FP_IOC_CAPTURE_IMAGE, &driver_image);
    if (ret < 0) {
        free(driver_image.data);
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    /* Copy image data */
    image->width = driver_image.width;
    image->height = driver_image.height;
    image->format = driver_image.format;
    image->quality = driver_image.quality;
    image->size = driver_image.size;
    
    /* Allocate and copy image data */
    image->data = malloc(image->size);
    if (!image->data) {
        free(driver_image.data);
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_MEMORY;
    }
    
    memcpy(image->data, driver_image.data, image->size);
    free(driver_image.data);
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Free image data
 */
void fp_xiaomi_free_image(fp_xiaomi_image_t *image)
{
    if (image && image->data) {
        free(image->data);
        image->data = NULL;
        image->size = 0;
    }
}

/**
 * Start fingerprint enrollment
 */
int fp_xiaomi_enroll_start(fp_xiaomi_device_t *device, uint8_t template_id, 
                          const char *name, uint32_t timeout_ms)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_enroll_params params;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Prepare enrollment parameters */
    memset(&params, 0, sizeof(params));
    params.template_id = template_id;
    if (name) {
        strncpy((char *)params.name, name, sizeof(params.name) - 1);
    }
    params.quality_threshold = FP_QUALITY_MEDIUM;
    params.max_attempts = 5;
    params.timeout_ms = timeout_ms ? timeout_ms : FP_TIMEOUT_DEFAULT;
    
    ret = ioctl(dev->fd, FP_IOC_ENROLL_START, &params);
    
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Continue fingerprint enrollment
 */
int fp_xiaomi_enroll_continue(fp_xiaomi_device_t *device)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    ret = ioctl(dev->fd, FP_IOC_ENROLL_CONTINUE);
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Complete fingerprint enrollment
 */
int fp_xiaomi_enroll_complete(fp_xiaomi_device_t *device, fp_xiaomi_template_t *template)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_template_data driver_template;
    int ret;
    
    if (!dev || !dev->initialized || !template) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Allocate template buffer */
    driver_template.data = malloc(FP_XIAOMI_MAX_TEMPLATE_SIZE);
    if (!driver_template.data) {
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_MEMORY;
    }
    
    ret = ioctl(dev->fd, FP_IOC_ENROLL_COMPLETE, &driver_template);
    if (ret < 0) {
        free(driver_template.data);
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    /* Copy template data */
    template->id = driver_template.id;
    template->type = driver_template.type;
    template->quality = driver_template.quality;
    template->size = driver_template.size;
    strncpy(template->name, (char *)driver_template.name, sizeof(template->name) - 1);
    
    /* Allocate and copy template data */
    template->data = malloc(template->size);
    if (!template->data) {
        free(driver_template.data);
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_MEMORY;
    }
    
    memcpy(template->data, driver_template.data, template->size);
    free(driver_template.data);
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Cancel fingerprint enrollment
 */
int fp_xiaomi_enroll_cancel(fp_xiaomi_device_t *device)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    ret = ioctl(dev->fd, FP_IOC_ENROLL_CANCEL);
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Verify fingerprint
 */
int fp_xiaomi_verify(fp_xiaomi_device_t *device, uint8_t template_id, uint32_t timeout_ms)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_verify_params params;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Prepare verification parameters */
    memset(&params, 0, sizeof(params));
    params.template_id = template_id;
    params.quality_threshold = FP_QUALITY_MEDIUM;
    params.timeout_ms = timeout_ms ? timeout_ms : FP_TIMEOUT_DEFAULT;
    
    ret = ioctl(dev->fd, FP_IOC_VERIFY, &params);
    
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Identify fingerprint
 */
int fp_xiaomi_identify(fp_xiaomi_device_t *device, uint8_t *matched_id, 
                      uint8_t *confidence, uint32_t timeout_ms)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    struct fp_identify_params params;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Prepare identification parameters */
    memset(&params, 0, sizeof(params));
    params.quality_threshold = FP_QUALITY_MEDIUM;
    params.timeout_ms = timeout_ms ? timeout_ms : FP_TIMEOUT_DEFAULT;
    
    ret = ioctl(dev->fd, FP_IOC_IDENTIFY, &params);
    if (ret < 0) {
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    /* Return results */
    if (matched_id) *matched_id = params.matched_id;
    if (confidence) *confidence = params.confidence;
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Free template data
 */
void fp_xiaomi_free_template(fp_xiaomi_template_t *template)
{
    if (template && template->data) {
        free(template->data);
        template->data = NULL;
        template->size = 0;
    }
}

/**
 * List stored templates
 */
int fp_xiaomi_list_templates(fp_xiaomi_device_t *device, uint8_t *template_ids, 
                            size_t *count)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    uint8_t driver_list[FP_XIAOMI_MAX_TEMPLATES];
    int ret;
    size_t i, found_count = 0;
    
    if (!dev || !dev->initialized || !template_ids || !count) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    ret = ioctl(dev->fd, FP_IOC_LIST_TEMPLATES, driver_list);
    if (ret < 0) {
        pthread_mutex_unlock(&dev->mutex);
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    /* Count and copy valid template IDs */
    for (i = 0; i < FP_XIAOMI_MAX_TEMPLATES && found_count < *count; i++) {
        if (driver_list[i] != 0) {
            template_ids[found_count] = driver_list[i];
            found_count++;
        }
    }
    
    *count = found_count;
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Delete template
 */
int fp_xiaomi_delete_template(fp_xiaomi_device_t *device, uint8_t template_id)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    ret = ioctl(dev->fd, FP_IOC_DELETE_TEMPLATE, &template_id);
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Clear all templates
 */
int fp_xiaomi_clear_templates(fp_xiaomi_device_t *device)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    ret = ioctl(dev->fd, FP_IOC_CLEAR_TEMPLATES);
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Reset device
 */
int fp_xiaomi_reset_device(fp_xiaomi_device_t *device)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    int ret;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    ret = ioctl(dev->fd, FP_IOC_RESET_DEVICE);
    pthread_mutex_unlock(&dev->mutex);
    
    if (ret < 0) {
        return FP_XIAOMI_ERROR_DEVICE;
    }
    
    return FP_XIAOMI_SUCCESS;
}

/**
 * Event handling thread
 */
static void *event_thread_func(void *arg)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)arg;
    fd_set readfds;
    struct timeval timeout;
    int ret;
    
    while (dev->event_thread_running) {
        FD_ZERO(&readfds);
        FD_SET(dev->fd, &readfds);
        
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        
        ret = select(dev->fd + 1, &readfds, NULL, NULL, &timeout);
        if (ret > 0 && FD_ISSET(dev->fd, &readfds)) {
            /* Device has data available - this indicates an event */
            if (dev->event_callback) {
                fp_xiaomi_event_t event;
                event.type = FP_XIAOMI_EVENT_FINGER_DETECTED;
                event.timestamp = time(NULL);
                
                dev->event_callback(device, &event, dev->callback_data);
            }
        }
    }
    
    return NULL;
}

/**
 * Set event callback
 */
int fp_xiaomi_set_event_callback(fp_xiaomi_device_t *device, 
                                fp_xiaomi_event_callback_t callback, void *user_data)
{
    struct fp_xiaomi_device_internal *dev = (struct fp_xiaomi_device_internal *)device;
    
    if (!dev || !dev->initialized) {
        errno = EINVAL;
        return FP_XIAOMI_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&dev->mutex);
    
    /* Stop existing event thread */
    if (dev->event_thread_running) {
        dev->event_thread_running = false;
        pthread_cancel(dev->event_thread);
        pthread_join(dev->event_thread, NULL);
    }
    
    /* Set new callback */
    dev->event_callback = callback;
    dev->callback_data = user_data;
    
    /* Start event thread if callback is set */
    if (callback) {
        dev->event_thread_running = true;
        if (pthread_create(&dev->event_thread, NULL, event_thread_func, dev) != 0) {
            dev->event_thread_running = false;
            dev->event_callback = NULL;
            dev->callback_data = NULL;
            pthread_mutex_unlock(&dev->mutex);
            return FP_XIAOMI_ERROR_DEVICE;
        }
    }
    
    pthread_mutex_unlock(&dev->mutex);
    return FP_XIAOMI_SUCCESS;
}

/**
 * Get error string
 */
const char *fp_xiaomi_get_error_string(int error_code)
{
    switch (error_code) {
    case FP_XIAOMI_SUCCESS:
        return "Success";
    case FP_XIAOMI_ERROR_DEVICE:
        return "Device error";
    case FP_XIAOMI_ERROR_PROTOCOL:
        return "Protocol error";
    case FP_XIAOMI_ERROR_TIMEOUT:
        return "Timeout";
    case FP_XIAOMI_ERROR_NO_FINGER:
        return "No finger detected";
    case FP_XIAOMI_ERROR_BAD_IMAGE:
        return "Bad image quality";
    case FP_XIAOMI_ERROR_NO_MATCH:
        return "No match found";
    case FP_XIAOMI_ERROR_HARDWARE:
        return "Hardware error";
    case FP_XIAOMI_ERROR_FIRMWARE:
        return "Firmware error";
    case FP_XIAOMI_ERROR_BUSY:
        return "Device busy";
    case FP_XIAOMI_ERROR_MEMORY:
        return "Memory allocation error";
    case FP_XIAOMI_ERROR_INVALID_PARAM:
        return "Invalid parameter";
    case FP_XIAOMI_ERROR_NOT_SUPPORTED:
        return "Operation not supported";
    case FP_XIAOMI_ERROR_PERMISSION:
        return "Permission denied";
    case FP_XIAOMI_ERROR_STORAGE_FULL:
        return "Storage full";
    case FP_XIAOMI_ERROR_TEMPLATE_EXIST:
        return "Template already exists";
    default:
        return "Unknown error";
    }
}