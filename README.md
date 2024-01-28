# **The WindowsPath Type** 
![Module Version](https://img.shields.io/badge/version-0.0.0-teal) ![Test Coverage](https://img.shields.io/badge/coverage-0%25-teal)


Author: Fabrice Sanga

The `WindowsPath` type performs operations on string instances that contain valid Windows File System path information. The specified path or file name string may point to a nonexistent file system object that is nonetheless valid and may carry information about locally or network shared files and directories.

The module also provides two validation attributes `ValidateWindowsPath` and `ValidateWindowsFileName`.

The most probable use case is to ensure that file name and path strings are validated before being used in a method or property. This can be useful for instance when validation of the file sytem object occurs before its creation.

<img src="https://gistcdn.githack.com/sangafabrice/a8c75d6031a491c0907d5ca5eb5587e0/raw/406120be7a900c3998e33d7302772827f20539f0/automation.svg" alt="Custom Powershell Module Icon" width="3%"> [![Downloads](https://img.shields.io/powershellgallery/dt/WindowsPath?color=blue&label=PSGallery%20%E2%AC%87%EF%B8%8F)](https://www.powershellgallery.com/packages/WindowsPath)

---