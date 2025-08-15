/*
 * Dell Precision 7780 Display Priority Manager
 * Unified executable combining all fix approaches
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <time.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>
#include <syslog.h>
#include <stdbool.h>
#include <stdarg.h>

#define VERSION "2.0.0"
#define LOG_FILE "/tmp/display_priority_manager.log"
#define LOCK_FILE "/tmp/display_priority_manager.lock"

// Fix modes
typedef enum {
    MODE_AUTO = 0,      // Auto-detect and apply best method
    MODE_KSCREEN,       // Use kscreen-doctor (default)
    MODE_CONFIG,        // Monitor and modify config files
    MODE_LIBRARY,       // Use LD_PRELOAD library injection
    MODE_CHECK,         // Check only, don't fix
    MODE_DAEMON         // Run as daemon monitoring for changes
} FixMode;

// Global options
static struct {
    FixMode mode;
    bool verbose;
    bool debug;
    bool force;
    bool dry_run;
    bool use_syslog;
    int max_retries;
    int retry_delay;
    const char* log_file;
} options = {
    .mode = MODE_AUTO,
    .verbose = false,
    .debug = false,
    .force = false,
    .dry_run = false,
    .use_syslog = false,
    .max_retries = 3,
    .retry_delay = 5,
    .log_file = LOG_FILE
};

// Logging functions
static FILE* log_fp = NULL;

static void log_message(const char* level, const char* format, ...) {
    va_list args;
    time_t now;
    struct tm* tm_info;
    char timestamp[64];
    
    time(&now);
    tm_info = localtime(&now);
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);
    
    va_start(args, format);
    
    if (options.use_syslog) {
        int priority = LOG_INFO;
        if (strcmp(level, "ERROR") == 0) priority = LOG_ERR;
        else if (strcmp(level, "WARNING") == 0) priority = LOG_WARNING;
        else if (strcmp(level, "DEBUG") == 0) priority = LOG_DEBUG;
        
        vsyslog(priority, format, args);
    }
    
    if (log_fp) {
        fprintf(log_fp, "[%s] %s: ", timestamp, level);
        vfprintf(log_fp, format, args);
        fprintf(log_fp, "\n");
        fflush(log_fp);
    }
    
    if (options.verbose || strcmp(level, "ERROR") == 0) {
        fprintf(stderr, "[%s] %s: ", timestamp, level);
        vfprintf(stderr, format, args);
        fprintf(stderr, "\n");
    }
    
    va_end(args);
}

#define DPM_LOG_INFO(fmt, ...) log_message("INFO", fmt, ##__VA_ARGS__)
#define DPM_LOG_ERROR(fmt, ...) log_message("ERROR", fmt, ##__VA_ARGS__)
#define DPM_LOG_WARNING(fmt, ...) log_message("WARNING", fmt, ##__VA_ARGS__)
#define DPM_LOG_DEBUG(fmt, ...) if (options.debug) log_message("DEBUG", fmt, ##__VA_ARGS__)

// Hardware detection
static bool check_dell_precision_7780(void) {
    char vendor[256] = {0};
    char product[256] = {0};
    FILE* fp;
    
    fp = fopen("/sys/class/dmi/id/sys_vendor", "r");
    if (fp) {
        fgets(vendor, sizeof(vendor), fp);
        fclose(fp);
    }
    
    fp = fopen("/sys/class/dmi/id/product_name", "r");
    if (fp) {
        fgets(product, sizeof(product), fp);
        fclose(fp);
    }
    
    // Remove newlines
    vendor[strcspn(vendor, "\n")] = 0;
    product[strcspn(product, "\n")] = 0;
    
    DPM_LOG_DEBUG("Hardware: %s %s", vendor, product);
    
    if (!strstr(vendor, "Dell") || !strstr(product, "Precision 7780")) {
        DPM_LOG_INFO("Not a Dell Precision 7780 - found: %s %s", vendor, product);
        return false;
    }
    
    return true;
}

static bool check_nvidia_discrete(void) {
    // Check for NVIDIA driver
    if (access("/proc/driver/nvidia", F_OK) != 0) {
        DPM_LOG_DEBUG("NVIDIA driver not loaded");
        return false;
    }
    
    // Check for discrete GPU via lspci
    FILE* fp = popen("lspci | grep -i nvidia", "r");
    if (!fp) return false;
    
    char line[512];
    bool has_nvidia = false;
    while (fgets(line, sizeof(line), fp)) {
        has_nvidia = true;
        DPM_LOG_DEBUG("Found NVIDIA device: %s", line);
    }
    pclose(fp);
    
    if (!has_nvidia) {
        DPM_LOG_INFO("NVIDIA GPU not found");
        return false;
    }
    
    // Check if Intel graphics is present (if so, not in discrete-only mode)
    fp = popen("lspci | grep -i 'intel.*graphics\\|intel.*vga'", "r");
    if (!fp) return true;
    
    bool has_intel = false;
    while (fgets(line, sizeof(line), fp)) {
        has_intel = true;
        DPM_LOG_DEBUG("Found Intel graphics: %s", line);
    }
    pclose(fp);
    
    if (has_intel) {
        DPM_LOG_INFO("Intel graphics present - not in discrete-only mode");
        return false;
    }
    
    return true;
}

static int count_connected_displays(void) {
    FILE* fp = popen("find /sys/class/drm -name 'card*-*' -exec cat {}/status \\; 2>/dev/null | grep -c 'connected'", "r");
    if (!fp) return 0;
    
    char buffer[32];
    int count = 0;
    if (fgets(buffer, sizeof(buffer), fp)) {
        count = atoi(buffer);
    }
    pclose(fp);
    
    DPM_LOG_DEBUG("Connected displays: %d", count);
    return count;
}

static bool should_apply_fix(void) {
    if (options.force) {
        DPM_LOG_INFO("Force mode enabled - skipping hardware checks");
        return true;
    }
    
    if (!check_dell_precision_7780()) {
        return false;
    }
    
    if (!check_nvidia_discrete()) {
        return false;
    }
    
    if (count_connected_displays() < 2) {
        DPM_LOG_INFO("Multiple displays not detected");
        return false;
    }
    
    DPM_LOG_INFO("Hardware checks passed - fix should be applied");
    return true;
}

// Display information structure
typedef struct {
    char name[64];
    int priority;
    bool is_internal;
} DisplayInfo;

// Parse kscreen-doctor output
static int parse_kscreen_output(DisplayInfo** displays, int* count) {
    FILE* fp = popen("kscreen-doctor -o 2>/dev/null", "r");
    if (!fp) {
        DPM_LOG_ERROR("Failed to run kscreen-doctor");
        return -1;
    }
    
    *displays = NULL;
    *count = 0;
    int capacity = 0;
    
    char line[1024];
    char current_output[64] = {0};
    int current_priority = -1;
    
    while (fgets(line, sizeof(line), fp)) {
        // Remove ANSI color codes
        char clean_line[1024];
        int j = 0;
        for (int i = 0; line[i] && j < sizeof(clean_line)-1; i++) {
            if (line[i] == '\033') {
                // Skip ANSI escape sequence
                while (line[i] && line[i] != 'm') i++;
            } else {
                clean_line[j++] = line[i];
            }
        }
        clean_line[j] = '\0';
        
        // Check for Output line
        if (strstr(clean_line, "Output:")) {
            // Save previous display if valid
            if (current_output[0] && current_priority > 0) {
                if (*count >= capacity) {
                    capacity = capacity ? capacity * 2 : 4;
                    *displays = realloc(*displays, capacity * sizeof(DisplayInfo));
                }
                
                DisplayInfo* display = &(*displays)[(*count)++];
                strcpy(display->name, current_output);
                display->priority = current_priority;
                display->is_internal = strstr(current_output, "eDP") || strstr(current_output, "LVDS");
                
                DPM_LOG_DEBUG("Found display: %s (priority %d, internal=%d)", 
                         display->name, display->priority, display->is_internal);
            }
            
            // Parse new output name
            sscanf(clean_line, "%*s %*d %63s", current_output);
            current_priority = -1;
        }
        // Check for priority line
        else if (strstr(clean_line, "priority")) {
            sscanf(clean_line, "%*s %d", &current_priority);
        }
    }
    
    // Save last display
    if (current_output[0] && current_priority > 0) {
        if (*count >= capacity) {
            capacity = capacity ? capacity * 2 : 4;
            *displays = realloc(*displays, capacity * sizeof(DisplayInfo));
        }
        
        DisplayInfo* display = &(*displays)[(*count)++];
        strcpy(display->name, current_output);
        display->priority = current_priority;
        display->is_internal = strstr(current_output, "eDP") || strstr(current_output, "LVDS");
        
        DPM_LOG_DEBUG("Found display: %s (priority %d, internal=%d)", 
                 display->name, display->priority, display->is_internal);
    }
    
    pclose(fp);
    return 0;
}

// Apply fix using kscreen-doctor
static int apply_kscreen_fix(void) {
    DisplayInfo* displays = NULL;
    int display_count = 0;
    
    if (parse_kscreen_output(&displays, &display_count) < 0) {
        return -1;
    }
    
    if (display_count == 0) {
        DPM_LOG_ERROR("No displays found");
        free(displays);
        return -1;
    }
    
    // Find internal display
    DisplayInfo* internal_display = NULL;
    for (int i = 0; i < display_count; i++) {
        if (displays[i].is_internal) {
            internal_display = &displays[i];
            break;
        }
    }
    
    if (!internal_display) {
        DPM_LOG_WARNING("No internal display found");
        free(displays);
        return -1;
    }
    
    // Check if fix is needed
    if (internal_display->priority == 1) {
        DPM_LOG_INFO("Internal display already has priority 1 - no fix needed");
        free(displays);
        return 0;
    }
    
    DPM_LOG_INFO("Internal display %s has priority %d - fixing...", 
             internal_display->name, internal_display->priority);
    
    // Build kscreen-doctor command
    char command[2048];
    snprintf(command, sizeof(command), "kscreen-doctor output.%s.priority.1", 
             internal_display->name);
    
    // Set external displays to priority 2+
    int ext_priority = 2;
    for (int i = 0; i < display_count; i++) {
        if (!displays[i].is_internal) {
            char ext_cmd[256];
            snprintf(ext_cmd, sizeof(ext_cmd), " output.%s.priority.%d", 
                     displays[i].name, ext_priority++);
            strcat(command, ext_cmd);
        }
    }
    
    DPM_LOG_INFO("Executing: %s", command);
    
    if (options.dry_run) {
        DPM_LOG_INFO("Dry run mode - not executing command");
        free(displays);
        return 0;
    }
    
    int result = system(command);
    free(displays);
    
    if (result == 0) {
        DPM_LOG_INFO("Display priority fix applied successfully");
        return 0;
    } else {
        DPM_LOG_ERROR("Failed to apply display priority fix (exit code: %d)", result);
        return -1;
    }
}

// Main fix function that tries different methods
static int apply_display_fix(void) {
    switch (options.mode) {
        case MODE_KSCREEN:
        case MODE_AUTO:
            return apply_kscreen_fix();
            
        case MODE_CONFIG:
            DPM_LOG_ERROR("Config monitoring mode not yet implemented");
            return -1;
            
        case MODE_LIBRARY:
            DPM_LOG_ERROR("Library injection mode not yet implemented");
            return -1;
            
        case MODE_CHECK:
            {
                DisplayInfo* displays = NULL;
                int display_count = 0;
                
                if (parse_kscreen_output(&displays, &display_count) < 0) {
                    return -1;
                }
                
                printf("Display Configuration:\n");
                printf("----------------------\n");
                for (int i = 0; i < display_count; i++) {
                    printf("  %s: priority=%d %s\n", 
                           displays[i].name, 
                           displays[i].priority,
                           displays[i].is_internal ? "(internal)" : "(external)");
                }
                
                free(displays);
                return 0;
            }
            
        case MODE_DAEMON:
            DPM_LOG_ERROR("Daemon mode not yet implemented");
            return -1;
            
        default:
            DPM_LOG_ERROR("Unknown mode: %d", options.mode);
            return -1;
    }
}

// Signal handling
static volatile bool running = true;

static void signal_handler(int sig) {
    DPM_LOG_INFO("Received signal %d - shutting down", sig);
    running = false;
}

// Print usage
static void print_usage(const char* prog_name) {
    printf("Dell Precision 7780 Display Priority Manager v%s\n", VERSION);
    printf("Usage: %s [OPTIONS]\n\n", prog_name);
    printf("Options:\n");
    printf("  -m, --mode MODE      Fix mode: auto, kscreen, config, library, check, daemon\n");
    printf("  -v, --verbose        Enable verbose output\n");
    printf("  -d, --debug          Enable debug output\n");
    printf("  -f, --force          Force fix even if hardware doesn't match\n");
    printf("  -n, --dry-run        Show what would be done without making changes\n");
    printf("  -r, --retries N      Maximum retry attempts (default: 3)\n");
    printf("  -w, --wait SECONDS   Wait time between retries (default: 5)\n");
    printf("  -l, --log FILE       Log file path (default: %s)\n", LOG_FILE);
    printf("  -s, --syslog         Use syslog for logging\n");
    printf("  -h, --help           Show this help message\n");
    printf("  -V, --version        Show version information\n");
    printf("\nModes:\n");
    printf("  auto     - Automatically select best method (default)\n");
    printf("  kscreen  - Use kscreen-doctor to set priorities\n");
    printf("  config   - Monitor and modify KScreen config files\n");
    printf("  library  - Use LD_PRELOAD library injection\n");
    printf("  check    - Check current configuration only\n");
    printf("  daemon   - Run as daemon monitoring for changes\n");
}

// Main function
int main(int argc, char* argv[]) {
    static struct option long_options[] = {
        {"mode",     required_argument, 0, 'm'},
        {"verbose",  no_argument,       0, 'v'},
        {"debug",    no_argument,       0, 'd'},
        {"force",    no_argument,       0, 'f'},
        {"dry-run",  no_argument,       0, 'n'},
        {"retries",  required_argument, 0, 'r'},
        {"wait",     required_argument, 0, 'w'},
        {"log",      required_argument, 0, 'l'},
        {"syslog",   no_argument,       0, 's'},
        {"help",     no_argument,       0, 'h'},
        {"version",  no_argument,       0, 'V'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "m:vdfnr:w:l:shV", long_options, NULL)) != -1) {
        switch (opt) {
            case 'm':
                if (strcmp(optarg, "auto") == 0) options.mode = MODE_AUTO;
                else if (strcmp(optarg, "kscreen") == 0) options.mode = MODE_KSCREEN;
                else if (strcmp(optarg, "config") == 0) options.mode = MODE_CONFIG;
                else if (strcmp(optarg, "library") == 0) options.mode = MODE_LIBRARY;
                else if (strcmp(optarg, "check") == 0) options.mode = MODE_CHECK;
                else if (strcmp(optarg, "daemon") == 0) options.mode = MODE_DAEMON;
                else {
                    fprintf(stderr, "Unknown mode: %s\n", optarg);
                    return 1;
                }
                break;
            case 'v':
                options.verbose = true;
                break;
            case 'd':
                options.debug = true;
                options.verbose = true;
                break;
            case 'f':
                options.force = true;
                break;
            case 'n':
                options.dry_run = true;
                break;
            case 'r':
                options.max_retries = atoi(optarg);
                break;
            case 'w':
                options.retry_delay = atoi(optarg);
                break;
            case 'l':
                options.log_file = optarg;
                break;
            case 's':
                options.use_syslog = true;
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            case 'V':
                printf("Dell Precision 7780 Display Priority Manager v%s\n", VERSION);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    
    // Open log file
    if (options.log_file && !options.use_syslog) {
        log_fp = fopen(options.log_file, "a");
        if (!log_fp) {
            fprintf(stderr, "Warning: Failed to open log file %s: %s\n", 
                    options.log_file, strerror(errno));
        }
    }
    
    // Open syslog if requested
    if (options.use_syslog) {
        openlog("display-priority-manager", LOG_PID | LOG_CONS, LOG_USER);
    }
    
    // Set up signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    DPM_LOG_INFO("=== Display Priority Manager Starting (v%s) ===", VERSION);
    DPM_LOG_INFO("Mode: %d, Verbose: %d, Debug: %d, Force: %d, Dry-run: %d",
             options.mode, options.verbose, options.debug, options.force, options.dry_run);
    
    // Check if fix should be applied
    if (!should_apply_fix()) {
        DPM_LOG_INFO("Fix not needed for this hardware");
        if (log_fp) fclose(log_fp);
        if (options.use_syslog) closelog();
        return 0;
    }
    
    // Apply fix with retries
    int attempts = 0;
    int result = -1;
    
    while (attempts < options.max_retries && result != 0) {
        attempts++;
        DPM_LOG_INFO("Fix attempt %d of %d", attempts, options.max_retries);
        
        result = apply_display_fix();
        
        if (result == 0) {
            DPM_LOG_INFO("Display priority fix completed successfully");
            break;
        } else if (attempts < options.max_retries) {
            DPM_LOG_WARNING("Fix attempt %d failed, waiting %d seconds before retry...", 
                       attempts, options.retry_delay);
            sleep(options.retry_delay);
        }
    }
    
    if (result != 0) {
        DPM_LOG_ERROR("All fix attempts failed");
    }
    
    // Cleanup
    if (log_fp) fclose(log_fp);
    if (options.use_syslog) closelog();
    
    return result;
}