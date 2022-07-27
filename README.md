# GuruSwiftSDK

A Swift SDK for interacting with the Guru API.

# How to rebuild generated model class
From root of package:
```bash
xcrun coremlc compile VipnasEndToEnd.mlpackage .
xcrun coremlc generate VipnasEndToEnd.mlpackage . --language Swift
mv VipnasEndToEnd.mlmodelc Sources/GuruSwiftSDK
```

# How to run tests
The easiest way is to run them all from the `Test navigator` in XCode.
