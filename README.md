##What is hCODE
The heterogeneous Computing Oriented Development Environment (hCODE) design method and tools are proposed to simplify the creation, sharing, and software integration of FPGA hardware accelerators.

The project in this repository is the online IP manager part of hCODE platform. This hcode command line tool is modified from [CocoaPods](https://cocoapods.org/), which is a dependency manager for Swift and Objective-C Cocoa projects. Main modifications are adding hardware Specs and shell-and-ip design roles support for FPGA based acccelerators.

## Installation
These steps are based on Ubuntu 14.04

1. install build essentials  
*sudo apt-get -y install build-essential*

2. install ruby2.0 and ruby2.0-dev  
*sudo add-apt-repository -y ppa:brightbox/ruby-ng*  
*sudo apt-get update*  
*sudo apt-get -y install ruby2.0 ruby2.0-dev*  

3. install git and bundler  
*sudo apt-get -y install git*  
*sudo gem install bundle*  

4. Clone hCODE from Github  
*git clone https://github.com/hCODE-FPGA/hCODE*  

5. Install dependencies with bundle  
*cd hCODE*  
*bundle*  

6. Initialize setup the hCODE  
*cd bin*  
*./hcode setup*  

You can put the location of hcode executable script into PATH and use it for convenient.


## Usage examples
| Command                                   | Explain                                                                           |
| ------------------------------------------|:----------------------------------------------------------------------------------|
| ./hcode setup   							| Setup: pull the repo to ~/.hcode.													|
| ./hcode list    							| List all hcode projects.															|
| ./hcode search [text]						| Search hcode projects with [text] in their name.									|
| ./hcode search -full [text]				| Search hcode projects with [text] in their name, summary or description field.	|
| ./hcode spec cat [test]					| Print spec file of hcode project that name contains [text]						|
| ./hcode spec create [type] 				| Create a demo hcode.spec file of [type]											|
| ./hcode spec lint hcode.spec 				| Validate the json format of the SPEC file.										|
| ./hcode repo add [NAME] [URL]				| add a private repo to ~/.hcode/repos/[NAME]/										|
| ./hcode remove [NAME]						| remove private repo located at ~/.hcode/repose/[NAME]/							|
| ./hcode repo push [NAME] hcode.spec 		| push hcode.spec to ~/.hcode/repose/[NAME]/ repo 									|
| ./hcode ip create [NAME] [SHELL]			| Create ip template project of [NAME] using a [SHELL]								|
| ./hcode ip get [NAME] [TAG]				| Downloading a IP and a compatable SHELL.											|

## License
This project is licenced under the MIT license.
