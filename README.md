# Deca

A text editor written in the D programming language. Based off the website [Build Your Own Text Editor](https://viewsourcecode.org/snaptoken/kilo/) which is in turn based off of [kilo by antriez](https://github.com/antirez/kilo). Like 'kilo' the name 'deca' is a [decimal unit prefix](https://en.wikipedia.org/wiki/Deca-), and also starts with the letter 'D'. Kilo is 1000 in decimal while deca is 10. However deca attempts to match kilos origional goal of fitting in approximately 1000 lines of code, not 10. Deca also attempts to depend only on libc and the D standard libraries. No external dependencies.

Deca should work fine with VT100 terminal emulators.

Deca is run at the command line with the command `deca`. A blank file will be shown if no arguments are provided. A file can be opened by passing it as the first argument to the command: `deca wikipedia-text-editor.txt`.

Deca uses [Calendar Versioning](https://calver.org/) in the format `YYYY.MM.DD`.

## License

This repository is available under the BSD (BSD-3-Clause) license. See the LICENSE file for details.