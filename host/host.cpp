#include <cstdint>
#include <cstring>
#include <iostream>
#include <stdio.h>

#include <openenclave/host.h>
#include <openenclave/bits/result.h>
#include <openenclave/bits/types.h>

#include "../build/host/helloworld_u.h"

using namespace std;

oe_enclave_t *enclave = NULL;

void host_helloworld() {
  fprintf(stdout, "[HOST] Callback - Enclave called into host to print: Hello World!\n");
}

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

int main(int argc, const char *argv[]) {
  oe_result_t result;
  int ret = 0;
  oe_enclave_t *enclave = NULL;

  uint32_t flags = OE_ENCLAVE_FLAG_DEBUG;
  if (check_simulate_opt(&argc, argv)) {
    flags |= OE_ENCLAVE_FLAG_SIMULATE;
  }
  if (argc != 2) {
    cerr << "Usage: " << argv[0] << " <enclave_image_path> [ --simulate ]" << endl;
    ret = 1;
    goto exit;
  }

  cout << "Host: create enclave for image:" << argv[1] << endl;
  result = oe_create_helloworld_enclave(
      argv[1], OE_ENCLAVE_TYPE_SGX, flags, NULL, 0, &enclave);
  if (result != OE_OK) {
    fprintf(stderr,
        "oe_create_helloworld_enclave(): result=%u (%s)\n",
        result,
        oe_result_str(result));
    ret = 1;
    goto exit;
  }

  // request the enclave to print hello world
  result = enclave_helloworld(enclave);
  if (result != OE_OK) {
    fprintf(stderr,
        "enclave_helloworld(): result=%u (%s)\n",
        result,
        oe_result_str(result));
    ret = 1;
    goto exit;
  }

exit:
  cout << "Host: terminate the enclave" << endl;
  if (enclave)
    oe_terminate_enclave(enclave);
  return ret;
}
