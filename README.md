# `ruby-mx-25328`

`ruby-mx-25328` is a Ruby connector for Maxwell's MX 25328 multimeter.

## Installation

1.  Install Ruby, e.g.:

    ```
    $ apt install ruby
    ```

2.  Clone this project:

    ```
    $ git clone https://github.com/gbence/ruby-mx-25328 && cd ruby-mx-25328
    ```

3.  Install dependencies:

    ```
    $ bundle install
    ```

## Usage

Connect the multimeter to the computer via its USB cable and check for the
newly created a serial device at `/dev/ttyUSB0`.  Check its owner and
permissions to avoid connection issues.

Turn on the multimeter **and** also turn on its **RS232** output by pressing
its "RS232" button.

If all conditions are properly met starting `bin/mx-25328` will start writing
current values and its corresponding unit in CSV format to the console.

```
$ bin/mx-25328
12010000.0,"Ω"
12330000.0,"Ω"
12760000.0,"Ω"
13210000.0,"Ω"
0.25689999999999996,"V"
0.2191,"V"
0.2032,"V"
0.1955,"V"
0.19119999999999998,"V"
0.1731,"V"
0.1546,"V"
0.15,"V"
0.1469,"V"
...
```
