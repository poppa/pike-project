# pike-project
This is a console program that generates [Pike](https://pike.lysator.liu.se) module skeletons for both `CMOD`s (modules written in C) or `PMOD`s (modules written in Pike) which then can be installed via `pike -x module && pike -x module install`.

![Screenshot](https://raw.githubusercontent.com/poppa/pike-project/master/dump.png)

## Installing and running the program

`project.pike` is self contained and can be put pretty much anywhere. I put mine in `~/bin` as `pike-project`.

If installed in somewhere in `PATH` just run `pike-project` (or what ever you called it) and follow the guide. The generated module skeleton will be put in the same directory as the program is executed in.
