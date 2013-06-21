#include <dns_sd.h>
#include <errno.h>

#include "Network/Dnssd_stub.h"

static volatile int timeIn = 0;
static volatile int timeOut = 67108864;

int dns_sd_handler(DNSServiceRef ref);

DNSServiceErrorType dns_sd_browse(char *servicename, void *context) {
  DNSServiceErrorType error;
  DNSServiceRef ref;
  error = DNSServiceBrowse(&ref,
                            0, // flags
                            0, // interfaces (all)
                            servicename, // service name
                            "", // domains (all)
                            dns_sd_browse_callback, // see hs export
                            context);  // context

  if (error == kDNSServiceErr_NoError) {
    dns_sd_handler(ref);
    DNSServiceRefDeallocate(ref);
  }
  return error;
}

DNSServiceErrorType dns_sd_resolve(char *devicename, char *servicename, void *context) {
	DNSServiceErrorType error;
	DNSServiceRef ref;
	error = DNSServiceResolve(&ref,
							   0, // flags
							   0, // interfaces (this could be an arg)
							   devicename, // device name
							   servicename, // service name
							   "local.", // domain (this could be an arg)
							   dns_sd_resolve_callback, // see hs export
							   context); // context

	if (error == kDNSServiceErr_NoError) {
		dns_sd_handler(ref);
		DNSServiceRefDeallocate(ref);
	}
	return error;
}

// "cross-platform" "runloop"
int dns_sd_handler(DNSServiceRef ref) {
	int dns_sd_fd = DNSServiceRefSockFD(ref);
	int nfds = dns_sd_fd + 1;
	fd_set read_fds;
	struct timeval tv;
	int result;

	while (!timeIn) {
		FD_ZERO(&read_fds);
		FD_SET(dns_sd_fd, &read_fds);
		tv.tv_sec = timeOut;
		tv.tv_usec = 0;

		result = select(nfds, &read_fds, (fd_set*)NULL, (fd_set*)NULL, &tv);
		if (result > 0) {
			DNSServiceErrorType err = kDNSServiceErr_NoError;
			if (FD_ISSET(dns_sd_fd, &read_fds))
        err = DNSServiceProcessResult(ref);
			if (err)
        return err;

		} else {
			// so long as it isn't EINTR, lets do it again!
      // this happens a lot without +RTS -V0
      // but if you run it with -V0, bye bye speed
			if (errno != EINTR)
        return errno;
		}
    // This return 0 should mean you don't get results, but it just works...
    // Maybe with lots of devices it will fail.
    return 0;
	}
  return 0;
}

