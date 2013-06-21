# DNS Service Discovery Haskell Bindings

`dnssd` provides Haskell bindings to Multicast DNS (mDNS) and DNS
Service Discovery (DNS-SD). Also known as Bonjour or Avahi.

## Install

    cabal install dnssd

## Example

To find all local web servers.

```haskell
import Network.DNSSD
main = do
  servers <- dnsBrowse "_http._tcp"
  putStrLn . show $ servers
```

This should look something like this:

```
[
  SRecord {deviceName = "Maxwell\8217s Server",
           serviceName = "_http._tcp.", deviceDomain = "local."}
, SRecord {deviceName = "Jenkins",
           serviceName = "_http._tcp.", deviceDomain = "local."}
]
```

Find just one and then resolve it's IP and port.

```haskell
import Network.DNSSD

dnsAny :: String -> IO (Maybe SResolved)
dnsAny s = do
  things <- dnsBrowse s
  if null things
    then return Nothing
    else dnsResolve $ head things

main = do
  web <- dnsAny "_http._tcp"
  print web
```

## Cross Platform Status

Works on:

- Mac

Doesn't work on yet:

- Linux
- Windows

