List of key codes as seen by the 6502
-------------------------------------

The PS/2 controller returns both a RAW key code and a ASCII key, the following
table gives the key-code, the normal ASCII and the shifted-ASCII for each key
in a standard US keyboard, sorted by key position:

| Key (US)  | Code | ASCII  | Shift |
|-----------|------|--------|-------|
| ESC       |  76  |   1B   |       |
| F1        |  05  |   01   |       |
| F2        |  06  |   02   |       |
| F3        |  04  |   03   |       |
| F4        |  0C  |   04   |       |
| F5        |  03  |   05   |       |
| F6        |  0B  |   06   |       |
| F7        |  83  |   07   |       |
| F8        |  0A  |   08   |       |
| F9        |  01  |   09   |       |
| F10       |  09  |   0A   |       |
| F11       |  78  |   0B   |       |
| F12       |  07  |   0C   |       |
| `   ~     |  0E  | 60  7E |       |
| 1   !     |  16  | 31  21 |       |
| 2   @     |  1E  | 32  40 |       |
| 3   #     |  26  | 33  23 |       |
| 4   $     |  25  | 34  24 |       |
| 5   %     |  2E  | 35  25 |       |
| 6   ^     |  36  | 36  5E |       |
| 7   &     |  3D  | 37  26 |       |
| 8   *     |  3E  | 38  2A |       |
| 9   (     |  46  | 39  29 |       |
| 0   )     |  45  | 30  28 |       |
| -   _     |  4E  | 2D  5F |       |
| +   =     |  55  | 2B  3D |       |
| BackSpc   |  66  |   7F   |       |
| Tab       |  0D  |   0E   |       |
| Q         |  15  | 51  71 |       |
| W         |  1D  | 57  77 |       |
| E         |  24  | 45  65 |       |
| R         |  2D  | 52  72 |       |
| T         |  2C  | 54  74 |       |
| Y         |  35  | 59  79 |       |
| U         |  3C  | 55  75 |       |
| I         |  43  | 49  69 |       |
| O         |  44  | 4F  6F |       |
| P         |  4D  | 50  70 |       |
| [   {     |  54  | 5B  7B |       |
| ]   }     |  5B  | 5D  7D |       |
| \   ¦     |  5D  | 5C  7C |       |
| CapsLock  |  58  |   16   |       |
| A         |  1C  | 41  61 |       |
| S         |  1B  | 53  73 |       |
| D         |  23  | 44  64 |       |
| F         |  2B  | 46  66 |       |
| G         |  34  | 47  67 |       |
| H         |  33  | 48  68 |       |
| J         |  3B  | 4A  6A |       |
| K         |  42  | 4B  6B |       |
| L         |  4B  | 4C  6C |       |
| ;   :     |  4C  | 3B  3A |       |
| '   "     |  52  | 27  22 |       |
| Enter     |  5A  |   0D   |       |
| L-Shift   |  12  |   -    |   1   |
| Z         |  1A  | 5A  7A |       |
| X         |  22  | 58  78 |       |
| C         |  21  | 43  63 |       |
| V         |  2A  | 56  76 |       |
| B         |  32  | 42  62 |       |
| N         |  31  | 4E  6E |       |
| M         |  3A  | 4D  6D |       |
| ,   <     |  41  | 2C  3C |       |
| .   >     |  49  | 2E  3E |       |
| /   ?     |  4A  | 2F  3F |       |
| R-Shift   |  59  |   -    |   1   |
| Control   |  14  |   -    |   2   |
| L-Win     |  9F  |   -    |   8   |
| L-Alt     |  11  |   -    |   4   |
| Space     |  29  |   20   |       |
| R-Alt     |  91  |   -    |   4   |
| R-Win     |  A7  |   -    |   8   |
| Menu      |  AF  |   0F   |       |
| R-Ctrl    |  94  |   -    |   2   |
| PrintScr  | 92 FC |  18   |       |
| Alt+Print |  84  |    -   |       |
| ScrollLck |  7E  |   19   |       |
| Pause     | 94 77 |   17  |  2(*) |
| Ctrl+Pause |  FE  |   1A  |       |
| Insert    |  F0  |   12   |       |
| Home      |  EC  |   10   |       |
| Page-Up   |  FD  |   15   |       |
| Delete    |  F1  |   13   |       |
| End       |  E9  |   11   |       |
| Page-Dwn  |  FA  |   14   |       |
| Up        |  F5  |   1C   |       |
| Left      |  EB  |   1E   |       |
| Down      |  F2  |   1D   |       |
| Right     |  F4  |   1F   |       |
| NumLock   |  77  |   17   |       |
| Kp  /     |  CA  |   2F   |       |
| Kp  *     |  7C  |   2A   |       |
| Kp  -     |  7B  |   2D   |       |
| Kp  7     |  6C  |   37   |       |
| Kp  8     |  75  |   38   |       |
| Kp  9     |  7D  |   39   |       |
| Kp  4     |  6B  |   34   |       |
| Kp  5     |  73  |   35   |       |
| Kp  6     |  74  |   36   |       |
| Kp  1     |  69  |   31   |       |
| Kp  2     |  72  |   32   |       |
| Kp  3     |  7A  |   33   |       |
| Kp  0     |  70  |   30   |       |
| Kp  .     |  71  |   2E   |       |
| Kp  +     |  79  |   2B   |       |
| Kp  Enter |  DA  |   0D   |       |
| Keyboard OK | AA |    -   |       |

Note: For the Pause key, it is read as ASCII $17 with Control pressed, but the
Control key is unpressed immediatelly after releasing the key.

