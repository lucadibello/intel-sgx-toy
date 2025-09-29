#include <cstdint>
#include <cstring>
#include <ctime>
#include <iostream>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <openenclave/host.h>
#include <openenclave/trace.h>
#include <openenclave/bits/result.h>
#include <openenclave/bits/types.h>

#include "../build/host/calu_u.h"
#include "openenclave/log.h"

using namespace std;

oe_enclave_t *enclave = NULL;

// === Host calls
void host_customized_log(
    void* context,
    bool is_enclave,
    const struct tm* t,
    long int usecs,
    oe_log_level_t level,
    uint64_t host_thread_id,
    const char* message)
{
    char time[25];
    strftime(time, sizeof(time), "%Y-%m-%dT%H:%M:%S%z", t);

    FILE* log_file = NULL;
    if (level >= OE_LOG_LEVEL_WARNING)
    {
        log_file = (FILE*)context;
    }
    else
    {
        log_file = stderr;
    }

    fprintf(
        log_file,
        "%s.%06ld, %s, %s, %lx, %s",
        time,
        usecs,
        (is_enclave ? "E" : "H"),
        oe_log_level_strings[level],
        host_thread_id,
        message);
}

static FILE* enc_logfile = NULL;
void host_transfer_logs_to_file(const char* modified_log, size_t size)
{
    fprintf(enc_logfile, "%.*s", (int)size, modified_log);
}

void host_helloworld() {
  fprintf(stdout, "[HOST] Callback - Enclave called into host to print: Hello World!\n");
}
// === Host calls

bool check_simulate_opt(int *argc, const char *argv[]) {
  for (int i = 0; i < *argc; i++) {
    if (strcmp(argv[i], "--simulate") == 0) {
      cout << "Running in simulation mode" << endl;
      memmove(&argv[i], &argv[i + 1], (*argc - i) * sizeof(char *));
      (*argc)--;
      return true;
    }
  }
  return false;
}

const char* extract_log_dir(int *argc, const char *argv[]) {
  for (int i = 0; i < *argc - 1; i++) {
    if (strcmp(argv[i], "--log-dir") == 0) {
      const char* log_dir = argv[i + 1];
      memmove(&argv[i], &argv[i + 2], (*argc - i - 1) * sizeof(char *));
      (*argc) -= 2;
      return log_dir;
    }
  }
  return "log"; // default directory
}

bool create_directory(const char* dir_path) {
  struct stat st = {0};
  if (stat(dir_path, &st) == -1) {
    if (mkdir(dir_path, 0755) != 0) {
      cerr << "Error: Failed to create log directory: " << dir_path << endl;
      return false;
    }
  }
  return true;
}

int main(int argc, const char *argv[]) {
  oe_result_t result;
  int ret = 0;
  oe_enclave_t *enclave = NULL;
  FILE* out_file = NULL;

  // Declare variables at the beginning to avoid goto issues
  time_t now;
  struct tm* timeinfo;
  char timestamp[20];
  char host_log_filename[256];
  char enclave_log_filename[256];
  uint32_t flags;

  // Extract log directory parameter (default: "log")
  const char* log_dir = extract_log_dir(&argc, argv);
  if (!create_directory(log_dir)) {
    ret = 1;
    goto exit;
  }

  // Generate timestamp for log filenames
  now = time(0);
  timeinfo = localtime(&now);
  strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", timeinfo);

  // Create timestamped filename for host logs
  snprintf(host_log_filename, sizeof(host_log_filename), "%s/oe_host_out_%s.txt", log_dir, timestamp);

  // set log callback for host
  out_file = fopen(host_log_filename, "w");
  if (!out_file) {
    cerr << "Error: Failed to create host log file: " << host_log_filename << endl;
    ret = 1;
    goto exit;
  }
  oe_log_set_callback((void*)out_file, host_customized_log);

  // Create timestamped filename for enclave logs
  snprintf(enclave_log_filename, sizeof(enclave_log_filename), "%s/oe_enclave_out_%s.txt", log_dir, timestamp);

  // open file for enclave logs
  enc_logfile = fopen(enclave_log_filename, "w");
  if (!enc_logfile) {
    cerr << "Error: Failed to create enclave log file: " << enclave_log_filename << endl;
    ret = 1;
    goto exit;
  }

  flags = OE_ENCLAVE_FLAG_DEBUG;
  if (check_simulate_opt(&argc, argv)) {
    flags |= OE_ENCLAVE_FLAG_SIMULATE;
  }
  if (argc != 2) {
    cerr << "Usage: " << argv[0] << " [--log-dir <directory>] [--simulate] <enclave_image_path>" << endl;
    cerr << "  --log-dir <directory>  Directory for log files (default: 'log')" << endl;
    cerr << "  --simulate            Run in simulation mode" << endl;
    ret = 1;
    goto exit;
  }

  cout << "Host: Using log directory: " << log_dir << endl;
  cout << "Host: Host logs will be written to: " << host_log_filename << endl;
  cout << "Host: Enclave logs will be written to: " << enclave_log_filename << endl;
  cout << "Host: create enclave for image:" << argv[1] << endl;
  result = oe_create_calu_enclave(
      argv[1], OE_ENCLAVE_TYPE_SGX, flags, NULL, 0, &enclave);
  if (result != OE_OK) {
    fprintf(stderr,
        "oe_create_calu_enclave(): result=%u (%s)\n",
        result,
        oe_result_str(result));
    ret = 1;
    goto exit;
  }

  // Set callback for enclave logs
  result = enclave_set_log_callback(enclave);

  // request the enclave to print hello world
  result = enclave_helloworld(enclave);
  if (result != OE_OK) {
    fprintf(stderr,
        "enclave_calu(): result=%u (%s)\n",
        result,
        oe_result_str(result));
    ret = 1;
    goto exit;
  }

exit:
  cout << "Host: terminate the enclave" << endl;
  if (enclave)
    oe_terminate_enclave(enclave);
  if (out_file)
    fclose(out_file);
  if (enc_logfile)
    fclose(enc_logfile);
  return ret;
}
