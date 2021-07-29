# Overview

A highly extensible Markdown parser that pretends to be CommonMark compliant:

`Passed 108 (16.5644%) | Failed 375 (57.5153%) | Ignored 169 (25.9202%)`

*oh dear*

Anyway, super alpha, no docs for now, use at your own risk or just study the code since that's the interesting part.

And yes, *another* alpha library from your's truly.

## Performance

**KEEP IN MIND THIS LIBRARY IS ONLY PASSING 16%, SO IS PROBABLY DOING MUCH LESS WORK THAN IT SHOULD OTHERWISE BE DOING**

I modified commonmark-d's benchmark to include this library, and here are the results:

```
*** Parsing file content\2015-04-07_Auburn Sounds website is now live!.md
time dmarkdown     = 71 us, HTML length = 620
time hunt-markdown = 553 us, HTML length = 522
time commonmark-d  = 62 us, HTML length = 522
time markusdownus  = 25 us, HTML length = 528

*** Parsing file content\2015-11-17_First plugin Graillon in open beta!.md
time dmarkdown     = 31 us, HTML length = 865
time hunt-markdown = 1401 us, HTML length = 779
time commonmark-d  = 36 us, HTML length = 778
time markusdownus  = 15 us, HTML length = 777

*** Parsing file content\2015-11-26_Graillon 1.0 released.md
time dmarkdown     = 40 us, HTML length = 1840
time hunt-markdown = 247 us, HTML length = 1577
time commonmark-d  = 17 us, HTML length = 1577
time markusdownus  = 26 us, HTML length = 1598

*** Parsing file content\2016-02-04_Interested in shaping our future plugins&#63;.md
time dmarkdown     = 29 us, HTML length = 913
time hunt-markdown = 185 us, HTML length = 872
time commonmark-d  = 15 us, HTML length = 872
time markusdownus  = 17 us, HTML length = 820

*** Parsing file content\2016-02-08_Making a Windows VST plugin with D.md
time dmarkdown     = 805 us, HTML length = 9849
time hunt-markdown = 1626 us, HTML length = 8787
time commonmark-d  = 63 us, HTML length = 8775
time markusdownus  = 99 us, HTML length = 8862

*** Parsing file content\2016-06-22_Introducing Panagement.md
time dmarkdown     = 44 us, HTML length = 2063
time hunt-markdown = 201 us, HTML length = 1944
time commonmark-d  = 17 us, HTML length = 1944
time markusdownus  = 31 us, HTML length = 1930

*** Parsing file content\2016-08-22_Why AAX is not supported right now.md
time dmarkdown     = 33 us, HTML length = 1779
time hunt-markdown = 127 us, HTML length = 1691
time commonmark-d  = 16 us, HTML length = 1691
time markusdownus  = 25 us, HTML length = 1710

*** Parsing file content\2016-09-08_Panagement and Graillon 1.1 release.md
time dmarkdown     = 44 us, HTML length = 2016
time hunt-markdown = 251 us, HTML length = 1783
time commonmark-d  = 18 us, HTML length = 1783
time markusdownus  = 29 us, HTML length = 1834

*** Parsing file content\2016-09-16_PBR for Audio Software Interfaces.md
time dmarkdown     = 150 us, HTML length = 9637
time hunt-markdown = 1256 us, HTML length = 8929
time commonmark-d  = 202 us, HTML length = 8929
time markusdownus  = 219 us, HTML length = 8933

*** Parsing file content\2016-11-07_Panagement and Graillon 1.2 release.md
time dmarkdown     = 28 us, HTML length = 1091
time hunt-markdown = 144 us, HTML length = 980
time commonmark-d  = 14 us, HTML length = 980
time markusdownus  = 15 us, HTML length = 984

*** Parsing file content\2016-11-10_Running D without its runtime.md
time dmarkdown     = 6351 us, HTML length = 10362
time hunt-markdown = 2517 us, HTML length = 9056
time commonmark-d  = 86 us, HTML length = 9047
time markusdownus  = 94 us, HTML length = 9113

*** Parsing file content\2016-12-14_We are in Computer Music!.md
time dmarkdown     = 28 us, HTML length = 883
time hunt-markdown = 260 us, HTML length = 820
time commonmark-d  = 13 us, HTML length = 820
time markusdownus  = 14 us, HTML length = 808

*** Parsing file content\2017-02-13_Vibrant 2.0 released, free demo.md
time dmarkdown     = 28 us, HTML length = 1001
time hunt-markdown = 193 us, HTML length = 943
time commonmark-d  = 15 us, HTML length = 943
time markusdownus  = 18 us, HTML length = 934

*** Parsing file content\2017-07-27_Graillon 2 A New Effect for Live Voice Changing.md
time dmarkdown     = 49 us, HTML length = 1721
time hunt-markdown = 364 us, HTML length = 1574
time commonmark-d  = 19 us, HTML length = 1574
time markusdownus  = 24 us, HTML length = 1540

*** Parsing file content\2017-10-14_The History Of Vibrant.md
time dmarkdown     = 80 us, HTML length = 5620
time hunt-markdown = 491 us, HTML length = 5402
time commonmark-d  = 37 us, HTML length = 5402
time markusdownus  = 65 us, HTML length = 5386

*** Parsing file content\2018-01-18_Bringing AAX to you.md
time dmarkdown     = 49 us, HTML length = 1841
time hunt-markdown = 942 us, HTML length = 1576
time commonmark-d  = 18 us, HTML length = 1576
time markusdownus  = 53 us, HTML length = 1627

*** Parsing file content\2018-08-16_Introducing our new plug-in Couture.md
time dmarkdown     = 65 us, HTML length = 3250
time hunt-markdown = 512 us, HTML length = 3039
time commonmark-d  = 30 us, HTML length = 3039
time markusdownus  = 46 us, HTML length = 2918

*** Parsing file content\2019-03-01_A Consequential Update.md
time dmarkdown     = 160 us, HTML length = 9008
time hunt-markdown = 1973 us, HTML length = 7940
time commonmark-d  = 64 us, HTML length = 7940
time markusdownus  = 114 us, HTML length = 7970

*** Parsing file content\2019-08-14_Introducing Panagement 2.md
time dmarkdown     = 73 us, HTML length = 3951
time hunt-markdown = 513 us, HTML length = 3680
time commonmark-d  = 31 us, HTML length = 3680
time markusdownus  = 62 us, HTML length = 3611
```