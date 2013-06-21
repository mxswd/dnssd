module Network.DNSSD (dnsBrowse, dnsResolve, SRecord(..), SResolved(..)) where

import Foreign.C
import Foreign

import Data.IORef

import Data.List

-- | 'SRecord' is a record on the network.
-- They can be found from 'dnsBrowse' or constructed if the values are known.
data SRecord = SRecord { deviceName :: String
                       , serviceName :: String
                       , deviceDomain :: String
                       } deriving (Show, Eq)

-- yes, this is Eq, this is sufficient information to identify a device on
-- the network uniquely.

-- | 'SResolved' is a resolved network service.
-- You can use this information to connect to the device.
data SResolved = SResolved { fullname :: String
                           , hosttarget :: String
                           , port :: Int
                           , txt :: String
                           } deriving (Show)

-- resolve.{c,h}
foreign import ccall "resolve.h dns_sd_browse" c_browse :: CString -> Ptr () -> IO CInt
foreign import ccall "resolve.h dns_sd_resolve" c_resolve :: CString -> CString -> Ptr () -> IO CInt

-- c stdlib
foreign import ccall "ntohs" ntohs :: CUShort -> IO CUShort

-- BROWSE

-- | 'dnsBrowse' searches for devices that provide the 's' service.
dnsBrowse :: String -> IO [SRecord]
dnsBrowse s = do
  ref <- newIORef []
  ptr <- newStablePtr ref
  cstr <- newCString s
  _ <- c_browse cstr (castStablePtrToPtr ptr) -- bye bye ptr, see you in C land
  fmap nub $ readIORef ref

foreign export ccall dns_sd_browse_callback :: Ptr () -> CUInt -> CUInt -> CUInt -> CString -> CString -> CString -> Ptr () -> IO ()
dns_sd_browse_callback :: Ptr () -> CUInt -> CUInt -> CUInt -> CString -> CString -> CString -> Ptr () -> IO ()
dns_sd_browse_callback _ref _fla _int _err name typ domain cont = do
  -- if you have 2 interfaces onto the same network, you can get duplicate
  -- devices. i.e. wifi + ethernet, you get 2 of everything.
  -- since we know a device is unique by Eq, lets just nub at the end...
  -- they are however unique to the interface, but we discard the
  --  interface in favor of the all interface (0).
  ref <- deRefStablePtr $ castPtrToStablePtr cont -- TADA! it's back!
  f <- peekCString name
  g <- peekCString typ
  h <- peekCString domain
  modifyIORef ref (++ [SRecord f g h])

-- RESOLVE

-- | 'dnsResolve' returns a resolved record if one is found. If it is
-- known what the name of the device on the network to resolve is, an 'SRecord'
-- can be constructed and passed to 'dnsResolve' and it will return 'Just' if
-- available or 'Nothing' if it couldn't be found.
dnsResolve :: SRecord -> IO (Maybe SResolved)
dnsResolve (SRecord d s _dom) = do
  ref <- newIORef Nothing
  ptr <- newStablePtr ref
  dstr <- newCString d
  sstr <- newCString s
  _ <- c_resolve dstr sstr (castStablePtrToPtr ptr)
  readIORef ref

foreign export ccall dns_sd_resolve_callback :: Ptr () -> CUInt -> CUInt -> CUInt -> CString -> CString -> CUShort -> CUShort -> CString -> Ptr () -> IO ()
dns_sd_resolve_callback :: Ptr () -> CUInt -> CUInt -> CUInt -> CString -> CString -> CUShort -> CUShort -> CString -> Ptr () -> IO ()
dns_sd_resolve_callback _ref _fla _int _err name host po txtLen txtrec cont = do
  ref <- deRefStablePtr $ castPtrToStablePtr cont
  f <- peekCString name
  g <- peekCString host
  p <- ntohs po
  t <- peekCStringLen (txtrec, fromIntegral txtLen)
  writeIORef ref (Just $ SResolved f g (fromIntegral p) t)

