/**
 * @file libfp_xiaomi.h
 * @brief User-space library header for Xiaomi FPC Fingerprint Scanner
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * Header file for the user-space library providing high-level API
 * for the Xiaomi FPC fingerprint scanner driver.
 * 
 * @copyright GPL v2 License
 */

#ifndef _LIBFP_XIAOMI_H
#define _LIBFP_XIAOMI_H

#include <stdint.h>
#include <stdbool.h>
#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Library version */
#define LIBFP_XIAOMI_VERSION_STRING "1.0.0"

/* Maximum sizes */
#define FP_XIAOMI_MAX_IMAGE_SIZE    (200 * 200)
#define FP_XIAOMI_MAX_TEMPLATE_SIZE 1024
#define FP_XIAOMI_MAX_TEMPLATES     10
#define FP_XIAOMI_MAX_NAME_LEN      32

/* Error codes */
typedef enum {
    FP_XIAOMI_SUCCESS = 0,
    FP_XIAOMI_ERROR_DEVICE = -1,
    FP_XIAOMI_ERROR_PROTOCOL = -2,
    FP_XIAOMI_ERROR_TIMEOUT = -3,
    FP_XIAOMI_ERROR_NO_FINGER = -4,
    FP_XIAOMI_ERROR_BAD_IMAGE = -5,
    FP_XIAOMI_ERROR_NO_MATCH = -6,
    FP_XIAOMI_ERROR_HARDWARE = -7,
    FP_XIAOMI_ERROR_FIRMWARE = -8,
    FP_XIAOMI_ERROR_BUSY = -9,
    FP_XIAOMI_ERROR_MEMORY = -10,
    FP_XIAOMI_ERROR_INVALID_PARAM = -11,
    FP_XIAOMI_ERROR_NOT_SUPPORTED = -12,
    FP_XIAOMI_ERROR_PERMISSION = -13,
    FP_XIAOMI_ERROR_STORAGE_FULL = -14,
    FP_XIAOMI_ERROR_TEMPLATE_EXIST = -15
} fp_xiaomi_error_t;

/* Device states */
typedef enum {
    FP_XIAOMI_STATE_DISCONNECTED = 0,
    FP_XIAOMI_STATE_INITIALIZING = 1,
    FP_XIAOMI_STATE_READY = 2,
    FP_XIAOMI_STATE_CAPTURING = 3,
    FP_XIAOMI_STATE_PROCESSING = 4,
    FP_XIAOMI_STATE_ERROR = 5,
    FP_XIAOMI_STATE_SUSPENDED = 6
} fp_xiaomi_state_t;

/* Image formats */
typedef enum {
    FP_XIAOMI_IMG_FORMAT_RAW = 0,
    FP_XIAOMI_IMG_FORMAT_GRAY8 = 1,
    FP_XIAOMI_IMG_FORMAT_RGB24 = 2,
    FP_XIAOMI_IMG_FORMAT_COMPRESSED = 3
} fp_xiaomi_image_format_t;

/* Template types */
typedef enum {
    FP_XIAOMI_TEMPLATE_PROPRIETARY = 0,
    FP_XIAOMI_TEMPLATE_ISO_19794_2 = 1,
    FP_XIAOMI_TEMPLATE_ANSI_378 = 2
} fp_xiaomi_template_type_t;

/* Event types */
typedef enum {
    FP_XIAOMI_EVENT_FINGER_DETECTED = 1,
    FP_XIAOMI_EVENT_FINGER_REMOVED = 2,
    FP_XIAOMI_EVENT_IMAGE_CAPTURED = 3,
    FP_XIAOMI_EVENT_ENROLLMENT_PROGRESS = 4,
    FP_XIAOMI_EVENT_VERIFICATION_COMPLETE = 5,
    FP_XIAOMI_EVENT_ERROR = 6
} fp_xiaomi_event_type_t;

/* Opaque device handle */
typedef struct fp_xiaomi_device fp_xiaomi_device_t;

/* Device information structure */
typedef struct {
    uint16_t vendor_id;
    uint16_t product_id;
    char firmware_version[16];
    uint16_t image_width;
    uint16_t image_height;
    uint8_t template_count;
    uint32_t capabilities;
} fp_xiaomi_device_info_t;

/* Device status structure */
typedef struct {
    fp_xiaomi_state_t state;
    int last_error;
    uint32_t uptime_ms;
    uint32_t total_captures;
    uint32_t successful_matches;
    uint32_t failed_matches;
    uint32_t error_count;
} fp_xiaomi_status_t;

/* Image data structure */
typedef struct {
    uint16_t width;
    uint16_t height;
    fp_xiaomi_image_format_t format;
    uint8_t quality;
    uint32_t size;
    uint8_t *data;
} fp_xiaomi_image_t;

/* Template data structure */
typedef struct {
    uint8_t id;
    fp_xiaomi_template_type_t type;
    uint8_t quality;
    uint32_t size;
    char name[FP_XIAOMI_MAX_NAME_LEN];
    uint8_t *data;
} fp_xiaomi_template_t;

/* Event structure */
typedef struct {
    fp_xiaomi_event_type_t type;
    time_t timestamp;
    union {
        struct {
            uint8_t progress;
            uint8_t samples_needed;
        } enrollment;
        struct {
            bool matched;
            uint8_t template_id;
            uint8_t confidence;
        } verification;
        struct {
            int error_code;
            char message[64];
        } error;
    } data;
} fp_xiaomi_event_t;

/* Event callback function type */
typedef void (*fp_xiaomi_event_callback_t)(fp_xiaomi_device_t *device,
                                          const fp_xiaomi_event_t *event,
                                          void *user_data);

/* Library initialization and cleanup */

/**
 * Initialize the library
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_init(void);

/**
 * Cleanup the library
 */
void fp_xiaomi_cleanup(void);

/**
 * Get library version
 * @param major Major version number (output)
 * @param minor Minor version number (output)
 * @param patch Patch version number (output)
 */
void fp_xiaomi_get_version(int *major, int *minor, int *patch);

/* Device management */

/**
 * Open fingerprint device
 * @param device_path Path to device node (NULL for default)
 * @return Device handle on success, NULL on failure
 */
fp_xiaomi_device_t *fp_xiaomi_open_device(const char *device_path);

/**
 * Close fingerprint device
 * @param device Device handle
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_close_device(fp_xiaomi_device_t *device);

/**
 * Get device information
 * @param device Device handle
 * @param info Device information structure (output)
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_get_device_info(fp_xiaomi_device_t *device, fp_xiaomi_device_info_t *info);

/**
 * Get device status
 * @param device Device handle
 * @param status Device status structure (output)
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_get_status(fp_xiaomi_device_t *device, fp_xiaomi_status_t *status);

/**
 * Reset device
 * @param device Device handle
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_reset_device(fp_xiaomi_device_t *device);

/* Image capture */

/**
 * Capture fingerprint image
 * @param device Device handle
 * @param image Image structure (output, must be freed with fp_xiaomi_free_image)
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_capture_image(fp_xiaomi_device_t *device, fp_xiaomi_image_t *image);

/**
 * Free image data
 * @param image Image structure
 */
void fp_xiaomi_free_image(fp_xiaomi_image_t *image);

/* Enrollment */

/**
 * Start fingerprint enrollment
 * @param device Device handle
 * @param template_id Template ID (1-10)
 * @param name Template name (optional, can be NULL)
 * @param timeout_ms Timeout in milliseconds (0 for default)
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_enroll_start(fp_xiaomi_device_t *device, uint8_t template_id,
                          const char *name, uint32_t timeout_ms);

/**
 * Continue fingerprint enrollment (capture next sample)
 * @param device Device handle
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_enroll_continue(fp_xiaomi_device_t *device);

/**
 * Complete fingerprint enrollment
 * @param device Device handle
 * @param template Template structure (output, must be freed with fp_xiaomi_free_template)
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_enroll_complete(fp_xiaomi_device_t *device, fp_xiaomi_template_t *template);

/**
 * Cancel fingerprint enrollment
 * @param device Device handle
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_enroll_cancel(fp_xiaomi_device_t *device);

/* Authentication */

/**
 * Verify fingerprint against specific template
 * @param device Device handle
 * @param template_id Template ID to verify against
 * @param timeout_ms Timeout in milliseconds (0 for default)
 * @return FP_XIAOMI_SUCCESS on match, FP_XIAOMI_ERROR_NO_MATCH on no match, other error codes on failure
 */
int fp_xiaomi_verify(fp_xiaomi_device_t *device, uint8_t template_id, uint32_t timeout_ms);

/**
 * Identify fingerprint against all stored templates
 * @param device Device handle
 * @param matched_id Matched template ID (output, only valid on success)
 * @param confidence Match confidence 0-100 (output, only valid on success)
 * @param timeout_ms Timeout in milliseconds (0 for default)
 * @return FP_XIAOMI_SUCCESS on match, FP_XIAOMI_ERROR_NO_MATCH on no match, other error codes on failure
 */
int fp_xiaomi_identify(fp_xiaomi_device_t *device, uint8_t *matched_id,
                      uint8_t *confidence, uint32_t timeout_ms);

/* Template management */

/**
 * List stored templates
 * @param device Device handle
 * @param template_ids Array to store template IDs (output)
 * @param count Size of array on input, number of templates found on output
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_list_templates(fp_xiaomi_device_t *device, uint8_t *template_ids, size_t *count);

/**
 * Delete stored template
 * @param device Device handle
 * @param template_id Template ID to delete
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_delete_template(fp_xiaomi_device_t *device, uint8_t template_id);

/**
 * Clear all stored templates
 * @param device Device handle
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_clear_templates(fp_xiaomi_device_t *device);

/**
 * Free template data
 * @param template Template structure
 */
void fp_xiaomi_free_template(fp_xiaomi_template_t *template);

/* Event handling */

/**
 * Set event callback function
 * @param device Device handle
 * @param callback Callback function (NULL to disable)
 * @param user_data User data passed to callback
 * @return FP_XIAOMI_SUCCESS on success, error code on failure
 */
int fp_xiaomi_set_event_callback(fp_xiaomi_device_t *device,
                                fp_xiaomi_event_callback_t callback,
                                void *user_data);

/* Utility functions */

/**
 * Get error string for error code
 * @param error_code Error code
 * @return Human-readable error string
 */
const char *fp_xiaomi_get_error_string(int error_code);

/* Convenience macros */

/**
 * Check if error code indicates success
 */
#define FP_XIAOMI_IS_SUCCESS(code) ((code) == FP_XIAOMI_SUCCESS)

/**
 * Check if error code indicates failure
 */
#define FP_XIAOMI_IS_ERROR(code) ((code) != FP_XIAOMI_SUCCESS)

/**
 * Default timeout values
 */
#define FP_XIAOMI_TIMEOUT_INFINITE  0
#define FP_XIAOMI_TIMEOUT_DEFAULT   5000
#define FP_XIAOMI_TIMEOUT_QUICK     1000
#define FP_XIAOMI_TIMEOUT_LONG      10000

/**
 * Quality thresholds
 */
#define FP_XIAOMI_QUALITY_MIN       0
#define FP_XIAOMI_QUALITY_LOW       25
#define FP_XIAOMI_QUALITY_MEDIUM    50
#define FP_XIAOMI_QUALITY_HIGH      75
#define FP_XIAOMI_QUALITY_MAX       100

#ifdef __cplusplus
}
#endif

#endif /* _LIBFP_XIAOMI_H */