/**
 * @file fp_test.c
 * @brief Test application for Xiaomi FPC Fingerprint Scanner
 * @author AI-Assisted Development
 * @version 1.0.0
 * 
 * Simple test application demonstrating the usage of the Xiaomi FPC
 * fingerprint scanner driver and user-space library.
 * 
 * @copyright GPL v2 License
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <time.h>

#include "libfp_xiaomi.h"

/* Global variables */
static fp_xiaomi_device_t *device = NULL;
static volatile bool running = true;

/* Signal handler for clean exit */
void signal_handler(int sig)
{
    printf("\nReceived signal %d, exiting...\n", sig);
    running = false;
}

/* Event callback function */
void event_callback(fp_xiaomi_device_t *dev, const fp_xiaomi_event_t *event, void *user_data)
{
    printf("Event received: ");
    
    switch (event->type) {
    case FP_XIAOMI_EVENT_FINGER_DETECTED:
        printf("Finger detected\n");
        break;
    case FP_XIAOMI_EVENT_FINGER_REMOVED:
        printf("Finger removed\n");
        break;
    case FP_XIAOMI_EVENT_IMAGE_CAPTURED:
        printf("Image captured\n");
        break;
    case FP_XIAOMI_EVENT_ENROLLMENT_PROGRESS:
        printf("Enrollment progress: %d%% (%d samples needed)\n",
               event->data.enrollment.progress,
               event->data.enrollment.samples_needed);
        break;
    case FP_XIAOMI_EVENT_VERIFICATION_COMPLETE:
        printf("Verification complete: %s (template %d, confidence %d%%)\n",
               event->data.verification.matched ? "MATCH" : "NO MATCH",
               event->data.verification.template_id,
               event->data.verification.confidence);
        break;
    case FP_XIAOMI_EVENT_ERROR:
        printf("Error: %s\n", event->data.error.message);
        break;
    default:
        printf("Unknown event type %d\n", event->type);
        break;
    }
}

/* Print device information */
void print_device_info(fp_xiaomi_device_t *dev)
{
    fp_xiaomi_device_info_t info;
    fp_xiaomi_status_t status;
    int ret;
    
    printf("=== Device Information ===\n");
    
    ret = fp_xiaomi_get_device_info(dev, &info);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("Vendor ID: 0x%04X\n", info.vendor_id);
        printf("Product ID: 0x%04X\n", info.product_id);
        printf("Firmware Version: %s\n", info.firmware_version);
        printf("Image Size: %dx%d\n", info.image_width, info.image_height);
        printf("Template Count: %d\n", info.template_count);
        printf("Capabilities: 0x%08X\n", info.capabilities);
    } else {
        printf("Failed to get device info: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    ret = fp_xiaomi_get_status(dev, &status);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("State: %d\n", status.state);
        printf("Uptime: %u ms\n", status.uptime_ms);
        printf("Total Captures: %u\n", status.total_captures);
        printf("Successful Matches: %u\n", status.successful_matches);
        printf("Failed Matches: %u\n", status.failed_matches);
        printf("Error Count: %u\n", status.error_count);
    } else {
        printf("Failed to get device status: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* List stored templates */
void list_templates(fp_xiaomi_device_t *dev)
{
    uint8_t template_ids[FP_XIAOMI_MAX_TEMPLATES];
    size_t count = FP_XIAOMI_MAX_TEMPLATES;
    int ret;
    
    printf("=== Stored Templates ===\n");
    
    ret = fp_xiaomi_list_templates(dev, template_ids, &count);
    if (ret == FP_XIAOMI_SUCCESS) {
        if (count == 0) {
            printf("No templates stored\n");
        } else {
            printf("Found %zu template(s):\n", count);
            for (size_t i = 0; i < count; i++) {
                printf("  Template ID: %d\n", template_ids[i]);
            }
        }
    } else {
        printf("Failed to list templates: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* Capture and save fingerprint image */
void capture_image(fp_xiaomi_device_t *dev)
{
    fp_xiaomi_image_t image;
    int ret;
    FILE *file;
    
    printf("=== Image Capture ===\n");
    printf("Place your finger on the scanner...\n");
    
    ret = fp_xiaomi_capture_image(dev, &image);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("Image captured: %dx%d, format %d, quality %d, size %u bytes\n",
               image.width, image.height, image.format, image.quality, image.size);
        
        /* Save image to file */
        file = fopen("fingerprint_image.raw", "wb");
        if (file) {
            fwrite(image.data, 1, image.size, file);
            fclose(file);
            printf("Image saved to fingerprint_image.raw\n");
        } else {
            printf("Failed to save image to file\n");
        }
        
        fp_xiaomi_free_image(&image);
    } else {
        printf("Failed to capture image: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* Enroll a new fingerprint */
void enroll_fingerprint(fp_xiaomi_device_t *dev, uint8_t template_id, const char *name)
{
    fp_xiaomi_template_t template;
    int ret;
    int samples = 0;
    
    printf("=== Fingerprint Enrollment ===\n");
    printf("Enrolling template ID %d (%s)\n", template_id, name ? name : "unnamed");
    
    ret = fp_xiaomi_enroll_start(dev, template_id, name, FP_XIAOMI_TIMEOUT_DEFAULT);
    if (ret != FP_XIAOMI_SUCCESS) {
        printf("Failed to start enrollment: %s\n", fp_xiaomi_get_error_string(ret));
        return;
    }
    
    printf("Enrollment started. Please scan your finger multiple times...\n");
    
    /* Continue enrollment until complete */
    while (samples < 5) {  /* Typically need 3-5 samples */
        printf("Sample %d: Place your finger on the scanner...\n", samples + 1);
        
        ret = fp_xiaomi_enroll_continue(dev);
        if (ret == FP_XIAOMI_SUCCESS) {
            samples++;
            printf("Sample captured successfully\n");
        } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
            printf("No finger detected, please try again\n");
            sleep(1);
            continue;
        } else if (ret == FP_XIAOMI_ERROR_BAD_IMAGE) {
            printf("Poor image quality, please try again\n");
            sleep(1);
            continue;
        } else {
            printf("Enrollment failed: %s\n", fp_xiaomi_get_error_string(ret));
            fp_xiaomi_enroll_cancel(dev);
            return;
        }
        
        sleep(1);  /* Brief pause between samples */
    }
    
    /* Complete enrollment */
    ret = fp_xiaomi_enroll_complete(dev, &template);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("Enrollment completed successfully!\n");
        printf("Template ID: %d\n", template.id);
        printf("Template Name: %s\n", template.name);
        printf("Template Quality: %d\n", template.quality);
        printf("Template Size: %u bytes\n", template.size);
        
        fp_xiaomi_free_template(&template);
    } else {
        printf("Failed to complete enrollment: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* Verify fingerprint */
void verify_fingerprint(fp_xiaomi_device_t *dev, uint8_t template_id)
{
    int ret;
    
    printf("=== Fingerprint Verification ===\n");
    printf("Verifying against template ID %d\n", template_id);
    printf("Place your finger on the scanner...\n");
    
    ret = fp_xiaomi_verify(dev, template_id, FP_XIAOMI_TIMEOUT_DEFAULT);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("Verification successful - MATCH!\n");
    } else if (ret == FP_XIAOMI_ERROR_NO_MATCH) {
        printf("Verification failed - NO MATCH\n");
    } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
        printf("No finger detected\n");
    } else if (ret == FP_XIAOMI_ERROR_BAD_IMAGE) {
        printf("Poor image quality\n");
    } else {
        printf("Verification failed: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* Identify fingerprint */
void identify_fingerprint(fp_xiaomi_device_t *dev)
{
    uint8_t matched_id;
    uint8_t confidence;
    int ret;
    
    printf("=== Fingerprint Identification ===\n");
    printf("Place your finger on the scanner...\n");
    
    ret = fp_xiaomi_identify(dev, &matched_id, &confidence, FP_XIAOMI_TIMEOUT_DEFAULT);
    if (ret == FP_XIAOMI_SUCCESS) {
        printf("Identification successful!\n");
        printf("Matched Template ID: %d\n", matched_id);
        printf("Confidence: %d%%\n", confidence);
    } else if (ret == FP_XIAOMI_ERROR_NO_MATCH) {
        printf("Identification failed - NO MATCH\n");
    } else if (ret == FP_XIAOMI_ERROR_NO_FINGER) {
        printf("No finger detected\n");
    } else if (ret == FP_XIAOMI_ERROR_BAD_IMAGE) {
        printf("Poor image quality\n");
    } else {
        printf("Identification failed: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    printf("\n");
}

/* Interactive menu */
void show_menu(void)
{
    printf("=== Xiaomi Fingerprint Scanner Test ===\n");
    printf("1. Show device information\n");
    printf("2. List stored templates\n");
    printf("3. Capture image\n");
    printf("4. Enroll fingerprint\n");
    printf("5. Verify fingerprint\n");
    printf("6. Identify fingerprint\n");
    printf("7. Delete template\n");
    printf("8. Clear all templates\n");
    printf("9. Reset device\n");
    printf("0. Exit\n");
    printf("Choice: ");
}

/* Main function */
int main(int argc, char *argv[])
{
    int ret;
    int choice;
    uint8_t template_id;
    char name[64];
    int major, minor, patch;
    
    /* Set up signal handlers */
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    printf("Xiaomi FPC Fingerprint Scanner Test Application\n");
    
    /* Get library version */
    fp_xiaomi_get_version(&major, &minor, &patch);
    printf("Library version: %d.%d.%d\n\n", major, minor, patch);
    
    /* Initialize library */
    ret = fp_xiaomi_init();
    if (ret != FP_XIAOMI_SUCCESS) {
        printf("Failed to initialize library: %s\n", fp_xiaomi_get_error_string(ret));
        return 1;
    }
    
    /* Open device */
    device = fp_xiaomi_open_device(NULL);  /* Use default device path */
    if (!device) {
        printf("Failed to open fingerprint device\n");
        printf("Make sure the driver is loaded and device is connected\n");
        fp_xiaomi_cleanup();
        return 1;
    }
    
    printf("Fingerprint device opened successfully\n\n");
    
    /* Set up event callback */
    ret = fp_xiaomi_set_event_callback(device, event_callback, NULL);
    if (ret != FP_XIAOMI_SUCCESS) {
        printf("Warning: Failed to set event callback: %s\n", fp_xiaomi_get_error_string(ret));
    }
    
    /* Interactive menu loop */
    while (running) {
        show_menu();
        
        if (scanf("%d", &choice) != 1) {
            printf("Invalid input\n");
            while (getchar() != '\n');  /* Clear input buffer */
            continue;
        }
        
        switch (choice) {
        case 1:
            print_device_info(device);
            break;
            
        case 2:
            list_templates(device);
            break;
            
        case 3:
            capture_image(device);
            break;
            
        case 4:
            printf("Enter template ID (1-10): ");
            if (scanf("%hhu", &template_id) == 1 && template_id >= 1 && template_id <= 10) {
                printf("Enter name (optional): ");
                if (scanf("%63s", name) == 1) {
                    enroll_fingerprint(device, template_id, name);
                } else {
                    enroll_fingerprint(device, template_id, NULL);
                }
            } else {
                printf("Invalid template ID\n");
            }
            break;
            
        case 5:
            printf("Enter template ID to verify: ");
            if (scanf("%hhu", &template_id) == 1) {
                verify_fingerprint(device, template_id);
            } else {
                printf("Invalid template ID\n");
            }
            break;
            
        case 6:
            identify_fingerprint(device);
            break;
            
        case 7:
            printf("Enter template ID to delete: ");
            if (scanf("%hhu", &template_id) == 1) {
                ret = fp_xiaomi_delete_template(device, template_id);
                if (ret == FP_XIAOMI_SUCCESS) {
                    printf("Template %d deleted successfully\n", template_id);
                } else {
                    printf("Failed to delete template: %s\n", fp_xiaomi_get_error_string(ret));
                }
            } else {
                printf("Invalid template ID\n");
            }
            break;
            
        case 8:
            printf("Are you sure you want to clear all templates? (y/N): ");
            if (getchar() == 'y' || getchar() == 'Y') {
                ret = fp_xiaomi_clear_templates(device);
                if (ret == FP_XIAOMI_SUCCESS) {
                    printf("All templates cleared successfully\n");
                } else {
                    printf("Failed to clear templates: %s\n", fp_xiaomi_get_error_string(ret));
                }
            }
            break;
            
        case 9:
            printf("Resetting device...\n");
            ret = fp_xiaomi_reset_device(device);
            if (ret == FP_XIAOMI_SUCCESS) {
                printf("Device reset successfully\n");
            } else {
                printf("Failed to reset device: %s\n", fp_xiaomi_get_error_string(ret));
            }
            break;
            
        case 0:
            running = false;
            break;
            
        default:
            printf("Invalid choice\n");
            break;
        }
        
        if (running) {
            printf("Press Enter to continue...");
            while (getchar() != '\n');  /* Wait for Enter */
            getchar();
            printf("\n");
        }
    }
    
    /* Cleanup */
    printf("Cleaning up...\n");
    
    if (device) {
        fp_xiaomi_close_device(device);
    }
    
    fp_xiaomi_cleanup();
    
    printf("Test application exited\n");
    return 0;
}