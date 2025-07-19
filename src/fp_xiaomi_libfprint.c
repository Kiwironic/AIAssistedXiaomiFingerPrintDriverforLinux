/**
 * @file fp_xiaomi_libfprint.c
 * @brief libfprint integration for Xiaomi FPC Fingerprint Scanner
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * libfprint driver integration for FPC Sensor Controller L:0001
 * This module provides proper integration with the Linux biometric
 * framework to fix device claiming and timeout issues.
 * 
 * @copyright GPL v2 License
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <glib.h>

/* libfprint includes */
#include <libfprint/fprint.h>
#include <libfprint/drivers_api.h>

/* Our driver includes */
#include "libfp_xiaomi.h"

/* Driver information */
#define DRIVER_NAME "xiaomi_fpc"
#define DRIVER_FULL_NAME "Xiaomi FPC Fingerprint Scanner"

/* Device identification */
static const FpIdEntry id_table[] = {
    { .vid = 0x10a5, .pid = 0x9201 },  /* FPC Sensor Controller L:0001 */
    { .vid = 0, .pid = 0, .driver_data = 0 },
};

/* Driver data structure */
struct _FpDeviceXiaomiFpc {
    FpDevice parent;
    fp_xiaomi_device_t *xiaomi_dev;
    gboolean device_claimed;
    GCancellable *cancellable;
    FpPrint *enroll_print;
    gint enroll_stage;
};

G_DECLARE_FINAL_TYPE(FpDeviceXiaomiFpc, fpi_device_xiaomi_fpc, FPI, DEVICE_XIAOMI_FPC, FpDevice)
G_DEFINE_TYPE(FpDeviceXiaomiFpc, fpi_device_xiaomi_fpc, FP_TYPE_DEVICE)

/* Forward declarations */
static void fpi_device_xiaomi_fpc_probe(FpDevice *device);
static void fpi_device_xiaomi_fpc_open(FpDevice *device);
static void fpi_device_xiaomi_fpc_close(FpDevice *device);
static void fpi_device_xiaomi_fpc_enroll(FpDevice *device);
static void fpi_device_xiaomi_fpc_verify(FpDevice *device);
static void fpi_device_xiaomi_fpc_identify(FpDevice *device);
static void fpi_device_xiaomi_fpc_cancel(FpDevice *device);

/**
 * Device probe function
 */
static void fpi_device_xiaomi_fpc_probe(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    GUsbDevice *usb_dev;
    gint vendor_id, product_id;
    
    g_debug("Probing Xiaomi FPC device");
    
    /* Get USB device information */
    usb_dev = fpi_device_get_usb_device(device);
    vendor_id = g_usb_device_get_vid(usb_dev);
    product_id = g_usb_device_get_pid(usb_dev);
    
    g_info("Found FPC device: %04x:%04x", vendor_id, product_id);
    
    /* Verify this is our target device */
    if (vendor_id != 0x10a5 || product_id != 0x9201) {
        fpi_device_probe_complete(device, NULL, NULL,
                                 g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_NOT_SUPPORTED,
                                           "Unsupported device"));
        return;
    }
    
    /* Set device properties */
    fpi_device_set_nr_enroll_stages(device, 5);  /* Typical enrollment stages */
    fpi_device_set_scan_type(device, FP_SCAN_TYPE_PRESS);
    
    /* Probe completed successfully */
    fpi_device_probe_complete(device, NULL, NULL, NULL);
}

/**
 * Device open function
 */
static void fpi_device_xiaomi_fpc_open(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    GError *error = NULL;
    
    g_debug("Opening Xiaomi FPC device");
    
    /* Initialize our library */
    if (fp_xiaomi_init() != FP_XIAOMI_SUCCESS) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                           "Failed to initialize Xiaomi FPC library");
        goto error;
    }
    
    /* Open the device */
    self->xiaomi_dev = fp_xiaomi_open_device(NULL);
    if (!self->xiaomi_dev) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                           "Failed to open Xiaomi FPC device");
        goto error;
    }
    
    /* Mark device as claimed to fix fprintd issues */
    self->device_claimed = TRUE;
    
    g_info("Xiaomi FPC device opened successfully");
    fpi_device_open_complete(device, NULL);
    return;
    
error:
    if (self->xiaomi_dev) {
        fp_xiaomi_close_device(self->xiaomi_dev);
        self->xiaomi_dev = NULL;
    }
    fp_xiaomi_cleanup();
    fpi_device_open_complete(device, error);
}

/**
 * Device close function
 */
static void fpi_device_xiaomi_fpc_close(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    
    g_debug("Closing Xiaomi FPC device");
    
    /* Cancel any ongoing operations */
    if (self->cancellable) {
        g_cancellable_cancel(self->cancellable);
        g_clear_object(&self->cancellable);
    }
    
    /* Close the device */
    if (self->xiaomi_dev) {
        fp_xiaomi_close_device(self->xiaomi_dev);
        self->xiaomi_dev = NULL;
    }
    
    /* Cleanup library */
    fp_xiaomi_cleanup();
    
    self->device_claimed = FALSE;
    
    g_info("Xiaomi FPC device closed");
    fpi_device_close_complete(device, NULL);
}

/**
 * Enrollment function
 */
static void fpi_device_xiaomi_fpc_enroll(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    FpPrint *print = NULL;
    GError *error = NULL;
    int ret;
    
    g_debug("Starting enrollment on Xiaomi FPC device");
    
    if (!self->xiaomi_dev || !self->device_claimed) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_NOT_OPEN,
                           "Device not properly opened or claimed");
        goto error;
    }
    
    /* Start enrollment */
    if (self->enroll_stage == 0) {
        ret = fp_xiaomi_enroll_start(self->xiaomi_dev, 1, "libfprint", 
                                    FP_XIAOMI_TIMEOUT_DEFAULT);
        if (ret != FP_XIAOMI_SUCCESS) {
            error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                               "Failed to start enrollment: %s",
                               fp_xiaomi_get_error_string(ret));
            goto error;
        }
        self->enroll_stage = 1;
    }
    
    /* Continue enrollment */
    ret = fp_xiaomi_enroll_continue(self->xiaomi_dev);
    
    if (ret == FP_XIAOMI_SUCCESS) {
        self->enroll_stage++;
        
        /* Check if enrollment is complete */
        if (self->enroll_stage >= fpi_device_get_nr_enroll_stages(device)) {
            fp_xiaomi_template_t template;
            
            ret = fp_xiaomi_enroll_complete(self->xiaomi_dev, &template);
            if (ret == FP_XIAOMI_SUCCESS) {
                /* Create libfprint print object */
                print = fp_print_new(device);
                
                /* Store template data in print */
                fpi_print_set_type(print, FPI_PRINT_RAW);
                fpi_print_set_device_stored(print, TRUE);
                
                /* Set print data */
                g_variant_builder_init(&builder, G_VARIANT_TYPE("ay"));
                for (guint i = 0; i < template.size; i++) {
                    g_variant_builder_add(&builder, "y", template.data[i]);
                }
                fpi_print_set_raw(print, g_variant_builder_end(&builder));
                
                fp_xiaomi_free_template(&template);
                
                g_info("Enrollment completed successfully");
                fpi_device_enroll_complete(device, print, NULL);
                
                self->enroll_stage = 0;
                return;
            }
        } else {
            /* Request next enrollment stage */
            fpi_device_enroll_progress(device, self->enroll_stage, print, NULL);
            return;
        }
    } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
        /* No finger detected, wait and retry */
        fpi_device_enroll_progress(device, self->enroll_stage, NULL, 
                                  g_error_new(FP_DEVICE_RETRY, FP_DEVICE_RETRY_TOO_SHORT,
                                            "Place finger on sensor"));
        return;
    } else if (ret == FP_XIAOMI_ERROR_BAD_IMAGE) {
        /* Poor image quality, retry */
        fpi_device_enroll_progress(device, self->enroll_stage, NULL,
                                  g_error_new(FP_DEVICE_RETRY, FP_DEVICE_RETRY_CENTER_FINGER,
                                            "Center finger on sensor"));
        return;
    }
    
    /* Enrollment failed */
    error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                       "Enrollment failed: %s", fp_xiaomi_get_error_string(ret));
    
error:
    if (self->xiaomi_dev) {
        fp_xiaomi_enroll_cancel(self->xiaomi_dev);
    }
    self->enroll_stage = 0;
    fpi_device_enroll_complete(device, NULL, error);
}

/**
 * Verification function
 */
static void fpi_device_xiaomi_fpc_verify(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    FpPrint *print;
    GError *error = NULL;
    int ret;
    
    g_debug("Starting verification on Xiaomi FPC device");
    
    if (!self->xiaomi_dev || !self->device_claimed) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_NOT_OPEN,
                           "Device not properly opened or claimed");
        goto error;
    }
    
    print = fpi_device_get_verify_data(device);
    if (!print) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_DATA_INVALID,
                           "No print data provided for verification");
        goto error;
    }
    
    /* Perform verification */
    ret = fp_xiaomi_verify(self->xiaomi_dev, 1, FP_XIAOMI_TIMEOUT_DEFAULT);
    
    if (ret == FP_XIAOMI_SUCCESS) {
        g_info("Verification successful - match found");
        fpi_device_verify_complete(device, FPI_MATCH_SUCCESS, print, NULL);
        return;
    } else if (ret == FP_XIAOMI_ERROR_NO_MATCH) {
        g_info("Verification failed - no match");
        fpi_device_verify_complete(device, FPI_MATCH_FAIL, NULL, NULL);
        return;
    } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
        error = g_error_new(FP_DEVICE_RETRY, FP_DEVICE_RETRY_TOO_SHORT,
                           "Place finger on sensor");
        fpi_device_verify_complete(device, FPI_MATCH_ERROR, NULL, error);
        return;
    }
    
    /* Verification error */
    error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                       "Verification failed: %s", fp_xiaomi_get_error_string(ret));
    
error:
    fpi_device_verify_complete(device, FPI_MATCH_ERROR, NULL, error);
}

/**
 * Identification function
 */
static void fpi_device_xiaomi_fpc_identify(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    GPtrArray *prints;
    FpPrint *match = NULL;
    GError *error = NULL;
    uint8_t matched_id, confidence;
    int ret;
    
    g_debug("Starting identification on Xiaomi FPC device");
    
    if (!self->xiaomi_dev || !self->device_claimed) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_NOT_OPEN,
                           "Device not properly opened or claimed");
        goto error;
    }
    
    prints = fpi_device_get_identify_data(device);
    if (!prints || prints->len == 0) {
        error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_DATA_INVALID,
                           "No prints provided for identification");
        goto error;
    }
    
    /* Perform identification */
    ret = fp_xiaomi_identify(self->xiaomi_dev, &matched_id, &confidence,
                            FP_XIAOMI_TIMEOUT_DEFAULT);
    
    if (ret == FP_XIAOMI_SUCCESS) {
        /* Find matching print in the provided list */
        if (matched_id > 0 && matched_id <= prints->len) {
            match = g_ptr_array_index(prints, matched_id - 1);
            g_info("Identification successful - matched template %d with %d%% confidence",
                   matched_id, confidence);
        }
        fpi_device_identify_complete(device, match, NULL);
        return;
    } else if (ret == FP_XIAOMI_ERROR_NO_MATCH) {
        g_info("Identification failed - no match found");
        fpi_device_identify_complete(device, NULL, NULL);
        return;
    } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
        error = g_error_new(FP_DEVICE_RETRY, FP_DEVICE_RETRY_TOO_SHORT,
                           "Place finger on sensor");
        fpi_device_identify_complete(device, NULL, error);
        return;
    }
    
    /* Identification error */
    error = g_error_new(FP_DEVICE_ERROR, FP_DEVICE_ERROR_GENERAL,
                       "Identification failed: %s", fp_xiaomi_get_error_string(ret));
    
error:
    fpi_device_identify_complete(device, NULL, error);
}

/**
 * Cancel operation function
 */
static void fpi_device_xiaomi_fpc_cancel(FpDevice *device)
{
    FpDeviceXiaomiFpc *self = FPI_DEVICE_XIAOMI_FPC(device);
    
    g_debug("Cancelling operation on Xiaomi FPC device");
    
    if (self->cancellable) {
        g_cancellable_cancel(self->cancellable);
    }
    
    if (self->xiaomi_dev) {
        /* Cancel any ongoing enrollment */
        fp_xiaomi_enroll_cancel(self->xiaomi_dev);
    }
    
    self->enroll_stage = 0;
}

/**
 * Class initialization
 */
static void fpi_device_xiaomi_fpc_class_init(FpDeviceXiaomiFpcClass *klass)
{
    FpDeviceClass *dev_class = FP_DEVICE_CLASS(klass);
    
    dev_class->id = "xiaomi_fpc";
    dev_class->full_name = DRIVER_FULL_NAME;
    dev_class->type = FP_DEVICE_TYPE_USB;
    dev_class->id_table = id_table;
    dev_class->scan_type = FP_SCAN_TYPE_PRESS;
    
    dev_class->probe = fpi_device_xiaomi_fpc_probe;
    dev_class->open = fpi_device_xiaomi_fpc_open;
    dev_class->close = fpi_device_xiaomi_fpc_close;
    dev_class->enroll = fpi_device_xiaomi_fpc_enroll;
    dev_class->verify = fpi_device_xiaomi_fpc_verify;
    dev_class->identify = fpi_device_xiaomi_fpc_identify;
    dev_class->cancel = fpi_device_xiaomi_fpc_cancel;
}

/**
 * Instance initialization
 */
static void fpi_device_xiaomi_fpc_init(FpDeviceXiaomiFpc *self)
{
    self->xiaomi_dev = NULL;
    self->device_claimed = FALSE;
    self->cancellable = NULL;
    self->enroll_print = NULL;
    self->enroll_stage = 0;
}