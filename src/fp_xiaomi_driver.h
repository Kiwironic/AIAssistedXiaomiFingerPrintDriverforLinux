/**
 * @file fp_xiaomi_driver.h
 * @brief Xiaomi FPC Fingerprint Scanner Linux Driver Header
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * Header file for Xiaomi FPC Fingerprint Reader driver
 * Contains IOCTL definitions, data structures, and constants
 * 
 * @copyright GPL v2 License
 */

#ifndef _FP_XIAOMI_DRIVER_H
#define _FP_XIAOMI_DRIVER_H

#include <linux/types.h>
#include <linux/ioctl.h>

/* IOCTL magic number */
#define FP_XIAOMI_IOC_MAGIC    'F'

/* Maximum sizes */
#define FP_XIAOMI_MAX_IMAGE_SIZE    (200 * 200)
#define FP_XIAOMI_MAX_TEMPLATE_SIZE 1024
#define FP_XIAOMI_MAX_TEMPLATES     10
#define FP_XIAOMI_MAX_NAME_LEN      32

/* Device capabilities flags */
#define FP_CAP_CAPTURE          0x0001
#define FP_CAP_VERIFY           0x0002
#define FP_CAP_IDENTIFY         0x0004
#define FP_CAP_TEMPLATE_STORAGE 0x0008
#define FP_CAP_LIVE_DETECTION   0x0010
#define FP_CAP_NAVIGATION       0x0020

/* Image formats */
enum fp_image_format {
    FP_IMG_FORMAT_RAW = 0,
    FP_IMG_FORMAT_GRAY8,
    FP_IMG_FORMAT_RGB24,
    FP_IMG_FORMAT_COMPRESSED
};

/* Template types */
enum fp_template_type {
    FP_TEMPLATE_PROPRIETARY = 0,
    FP_TEMPLATE_ISO_19794_2,
    FP_TEMPLATE_ANSI_378
};

/* Device information structure */
struct fp_device_info {
    __u16 vendor_id;
    __u16 product_id;
    __u8 firmware_version[16];
    __u16 image_width;
    __u16 image_height;
    __u8 template_count;
    __u32 capabilities;
    __u32 reserved[4];
};

/* Image data structure */
struct fp_image_data {
    __u16 width;
    __u16 height;
    __u8 format;
    __u8 quality;
    __u16 flags;
    __u32 size;
    __u8 *data;
};

/* Template data structure */
struct fp_template_data {
    __u8 id;
    __u8 type;
    __u8 quality;
    __u8 flags;
    __u32 size;
    __u8 name[FP_XIAOMI_MAX_NAME_LEN];
    __u8 *data;
};

/* Enrollment parameters */
struct fp_enroll_params {
    __u8 template_id;
    __u8 name[FP_XIAOMI_MAX_NAME_LEN];
    __u8 quality_threshold;
    __u8 max_attempts;
    __u32 timeout_ms;
    __u32 flags;
};

/* Verification parameters */
struct fp_verify_params {
    __u8 template_id;
    __u8 quality_threshold;
    __u32 timeout_ms;
    __u32 flags;
};

/* Identification parameters */
struct fp_identify_params {
    __u8 quality_threshold;
    __u32 timeout_ms;
    __u32 flags;
    __u8 matched_id;
    __u8 confidence;
    __u16 reserved;
};

/* Device status structure */
struct fp_device_status {
    __u8 state;
    __u8 last_error;
    __u16 flags;
    __u32 uptime_ms;
    __u32 total_captures;
    __u32 successful_matches;
    __u32 failed_matches;
    __u32 error_count;
    __u32 reserved[2];
};

/* Calibration parameters */
struct fp_calibration_params {
    __u8 mode;
    __u8 sensitivity;
    __u16 threshold;
    __u32 flags;
    __u32 reserved[3];
};

/* Power management parameters */
struct fp_power_params {
    __u8 mode;
    __u8 auto_suspend_delay;
    __u16 flags;
    __u32 reserved[2];
};

/* IOCTL commands */

/* Device information and control */
#define FP_IOC_GET_DEVICE_INFO    _IOR(FP_XIAOMI_IOC_MAGIC, 0x01, struct fp_device_info)
#define FP_IOC_GET_STATUS         _IOR(FP_XIAOMI_IOC_MAGIC, 0x02, struct fp_device_status)
#define FP_IOC_RESET_DEVICE       _IO(FP_XIAOMI_IOC_MAGIC, 0x03)
#define FP_IOC_CALIBRATE          _IOW(FP_XIAOMI_IOC_MAGIC, 0x04, struct fp_calibration_params)

/* Image capture */
#define FP_IOC_CAPTURE_IMAGE      _IOR(FP_XIAOMI_IOC_MAGIC, 0x10, struct fp_image_data)
#define FP_IOC_GET_IMAGE_SIZE     _IOR(FP_XIAOMI_IOC_MAGIC, 0x11, __u32)

/* Template management */
#define FP_IOC_ENROLL_START       _IOW(FP_XIAOMI_IOC_MAGIC, 0x20, struct fp_enroll_params)
#define FP_IOC_ENROLL_CONTINUE    _IO(FP_XIAOMI_IOC_MAGIC, 0x21)
#define FP_IOC_ENROLL_COMPLETE    _IOR(FP_XIAOMI_IOC_MAGIC, 0x22, struct fp_template_data)
#define FP_IOC_ENROLL_CANCEL      _IO(FP_XIAOMI_IOC_MAGIC, 0x23)

/* Template storage */
#define FP_IOC_STORE_TEMPLATE     _IOW(FP_XIAOMI_IOC_MAGIC, 0x30, struct fp_template_data)
#define FP_IOC_LOAD_TEMPLATE      _IOWR(FP_XIAOMI_IOC_MAGIC, 0x31, struct fp_template_data)
#define FP_IOC_DELETE_TEMPLATE    _IOW(FP_XIAOMI_IOC_MAGIC, 0x32, __u8)
#define FP_IOC_LIST_TEMPLATES     _IOR(FP_XIAOMI_IOC_MAGIC, 0x33, __u8[FP_XIAOMI_MAX_TEMPLATES])
#define FP_IOC_CLEAR_TEMPLATES    _IO(FP_XIAOMI_IOC_MAGIC, 0x34)

/* Authentication */
#define FP_IOC_VERIFY             _IOW(FP_XIAOMI_IOC_MAGIC, 0x40, struct fp_verify_params)
#define FP_IOC_IDENTIFY           _IOWR(FP_XIAOMI_IOC_MAGIC, 0x41, struct fp_identify_params)

/* Power management */
#define FP_IOC_SET_POWER_MODE     _IOW(FP_XIAOMI_IOC_MAGIC, 0x50, struct fp_power_params)
#define FP_IOC_GET_POWER_MODE     _IOR(FP_XIAOMI_IOC_MAGIC, 0x51, struct fp_power_params)

/* Debugging and diagnostics */
#define FP_IOC_GET_DEBUG_INFO     _IOR(FP_XIAOMI_IOC_MAGIC, 0x60, __u32[16])
#define FP_IOC_SET_DEBUG_LEVEL    _IOW(FP_XIAOMI_IOC_MAGIC, 0x61, __u8)

/* Maximum IOCTL number */
#define FP_IOC_MAXNR              0x61

/* Error codes returned by driver */
#define FP_SUCCESS                0
#define FP_ERROR_DEVICE          -1
#define FP_ERROR_PROTOCOL        -2
#define FP_ERROR_TIMEOUT         -3
#define FP_ERROR_NO_FINGER       -4
#define FP_ERROR_BAD_IMAGE       -5
#define FP_ERROR_NO_MATCH        -6
#define FP_ERROR_HARDWARE        -7
#define FP_ERROR_FIRMWARE        -8
#define FP_ERROR_BUSY            -9
#define FP_ERROR_MEMORY         -10
#define FP_ERROR_INVALID_PARAM  -11
#define FP_ERROR_NOT_SUPPORTED  -12
#define FP_ERROR_PERMISSION     -13
#define FP_ERROR_STORAGE_FULL   -14
#define FP_ERROR_TEMPLATE_EXIST -15

/* Device states */
#define FP_STATE_DISCONNECTED    0
#define FP_STATE_INITIALIZING    1
#define FP_STATE_READY           2
#define FP_STATE_CAPTURING       3
#define FP_STATE_PROCESSING      4
#define FP_STATE_ERROR           5
#define FP_STATE_SUSPENDED       6

/* Power modes */
#define FP_POWER_ACTIVE          0
#define FP_POWER_IDLE            1
#define FP_POWER_SLEEP           2
#define FP_POWER_DEEP_SLEEP      3

/* Calibration modes */
#define FP_CALIBRATE_FACTORY     0
#define FP_CALIBRATE_USER        1
#define FP_CALIBRATE_AUTO        2

/* Quality thresholds */
#define FP_QUALITY_MIN           0
#define FP_QUALITY_LOW           25
#define FP_QUALITY_MEDIUM        50
#define FP_QUALITY_HIGH          75
#define FP_QUALITY_MAX           100

/* Timeout values (milliseconds) */
#define FP_TIMEOUT_INFINITE      0
#define FP_TIMEOUT_DEFAULT       5000
#define FP_TIMEOUT_QUICK         1000
#define FP_TIMEOUT_LONG          10000

/* Flags for various operations */
#define FP_FLAG_LIVE_DETECTION   0x0001
#define FP_FLAG_QUALITY_CHECK    0x0002
#define FP_FLAG_FAST_MODE        0x0004
#define FP_FLAG_SECURE_MODE      0x0008
#define FP_FLAG_DEBUG_MODE       0x0010

#ifdef __KERNEL__

/* Kernel-only definitions */

/* Protocol commands */
#define FP_CMD_GET_INFO          0x01
#define FP_CMD_RESET             0x02
#define FP_CMD_CALIBRATE         0x03
#define FP_CMD_CAPTURE           0x10
#define FP_CMD_ENROLL_START      0x20
#define FP_CMD_ENROLL_CONTINUE   0x21
#define FP_CMD_ENROLL_COMPLETE   0x22
#define FP_CMD_VERIFY            0x30
#define FP_CMD_IDENTIFY          0x31
#define FP_CMD_STORE_TEMPLATE    0x40
#define FP_CMD_LOAD_TEMPLATE     0x41
#define FP_CMD_DELETE_TEMPLATE   0x42
#define FP_CMD_LIST_TEMPLATES    0x43
#define FP_CMD_SET_POWER         0x50
#define FP_CMD_GET_POWER         0x51

/* Response codes */
#define FP_RESP_OK               0x00
#define FP_RESP_ERROR            0x01
#define FP_RESP_TIMEOUT          0x02
#define FP_RESP_NO_FINGER        0x03
#define FP_RESP_BAD_IMAGE        0x04
#define FP_RESP_NO_MATCH         0x05
#define FP_RESP_BUSY             0x06
#define FP_RESP_NOT_SUPPORTED    0x07

/* Command/response packet structure */
struct fp_packet {
    __u8 cmd;
    __u8 flags;
    __u16 length;
    __u8 data[];
} __packed;

/* Firmware update structure */
struct fp_firmware_info {
    __u32 version;
    __u32 size;
    __u32 checksum;
    __u8 *data;
};

#endif /* __KERNEL__ */

#endif /* _FP_XIAOMI_DRIVER_H */