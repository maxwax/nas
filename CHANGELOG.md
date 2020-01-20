# CHANGELOG for 'nas' script

## 1.2.0

* Add check for root/sudo user. Avoids errors when I call this without sudo.

## 1.1.1 Better output

* Ignore lines that start with # for comments but ALSO ignore lines that are empty.

* Use printf on the output to get pretty column based output that is easier to read

## 1.1.0 Config file location

* Moving config file location to /etc/nas.conf for system wide use. This lets root use it as well as users calling it via sudo.

## 1.0.0 Adding versioning to 'nas' script

* Semantic versioning at v1.0.0 for use with releases and Chef automation

* Adding install script so release can be downloaded as .tgz file and installed via automation

* MIT license instead of Apache. Just moving all my misc scripts to MIT license
