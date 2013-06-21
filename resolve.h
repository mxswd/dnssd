#include <dns_sd.h>
#include <errno.h>

DNSServiceErrorType dns_sd_browse(char *servicename, void *context);
DNSServiceErrorType dns_sd_resolve(char *devicename, char *servicename, void *context);

