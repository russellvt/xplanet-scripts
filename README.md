
[Source](http://hans.ecke.ws/xplanet/ "Permalink to ")

![An xplanet image, using peters projection][1]

**THIS PROJECT HAS ENDED. IF YOU ARE INTERESTED IN CONTINUING IT, FEEL FREE TO TALK TO ME.**

This page is the home of some scripts that deal with _geographic information (GIS)_, especially related to the [xplanet][3] program **(Version 0.9x only, for now)**. They allow you to display **up-to-the-minute** information on **weather**, **earthquakes**, **hurricanes** and more on your computer. You can see how the results look like on [FlatPlanet][4] which uses all the below scripts.


***

All-in-one packages that should be unpacked into your xplanet directory (the directory with the images/ and markers/ subdirectories).

Windows users please read [this][5].

[Announcements archive][6] | [Mailing list][7].

| Program | Version | Updated | Usage |
| ------- | ------- | ------- | ----- |
| [geo_locator][8] |  2.1.5 |  02 May 2003 |  determine geographic locations |
| [weather][9] |  4.1.8 |  15 Jul 2003 |  display weather icons and temperatures on xplanet maps |
| [forecast][10] |  1.2.5 |  17 Jul 2003 |  display the weather forecast for your location on an xplanet map |
| [earthq][11] |  2.1.7 |  15 Jul 2003 |  display earthquake locations and magnitudes on xplanet maps |
| [volcano][12] |  2.1.5 |  05 May 2003 |  display active volcanos on xplanet maps |
| [hurricane][13] |  2.2.3 |  15 Jul 2003 |  display current hurricanes / storms on xplanet maps, with magnification |
| [visible-satellites][14] |  0.8.2 |  05 May 2003 |  display satellites visible from your home |
| [xplanet-update][15] |  0.9.7 |  15 Jul 2003 |  update your xplanet marker files, satellite info and cloud images |
| [image-stream][16] |  0.9.7 |  15 Jul 2003 |  continuous background process, creates a stream of current xplanet images |
| [moonphase][17] |  0.8.1 |  02 May 2003 |  show the phases of the moon |
| [xplanet Linux RPM][18] |  0.94-3 |  02 May 2003 |  Linux RPM's of xplanet with various problems fixed |
| [Windows binary][5] |  0.94-2 |  21 Feb 2003 |  Windows binary of xplanet with various problems fixed |

***

All scripts have been converted to a unified configuration scheme. You don't have to edit scripts (those .pl files) anymore. Instead you only adjust the xplanet.conf configuration file:

* Download the scripts and archives into your xplanet directory (the directory with the markers/ and images/ subdirectory)
* Execute them once
* They will write or update (if its already existing) the configuration file **xplanet.conf**
* Edit this file **only if you like to**. The most important options are on top.

Additionally, all source code published here is now under the [GNU General Public License][19].


***

### geo_locator and igeo

_geo_locator.pl_ is a perl script that determines the coordinates of locations around the world or finds locations near specific coordinates. Developed together with [Felix Andrews][20]. Formerly known as _xplanet-location.pl_.

_igeo.pl_ is an interactive version. It runs as a shell (using readline) and you can type your requests interactively, load different data sources or change the configuration.

_geo_locator.pl_ is mostly a drop-in replacement for the tzcoord.pl that comes with xplanet, but is much more powerful. The differences are:
  * it knows a _lot_ more locations, especially from the Getty Thesaurus
  * can perform inexact searches
  * can perform reverse lookup

It gets its information from:
  * your system's zone.tab file
  * xplanet marker files
  * [Getty Thesaurus of Geographic Names](http://www.getty.edu/research/tools/vocabulary/tgn/)

Last updated _02 May 2003_, Version 2.1.5: more robust; more code cleanup

Downloadable files:
  * README.geo_locator
  * README.igeo
  * ChangeLog
  * geo_locator_pl.tar.gz an archive containing all script- and marker files. Unpack into the xplanet directory, if you have xplanet installed. About 3 MB.
  * geo_locator_pl.zip the same archive, in ZIP format for Windows users

There are associated marker files:
  * ed_u.com (from the webpage of the same name)
  * bcca.org (from the webpage of the same name)
  * weather_markers
  * census2000_* (from the Census 2000 in the USA)
which contain more than 100000 locations.


***

### weather

This is a perl script which downloads weather information from [weather.yahoo.com][21] and [weather undergound][22] and writes a marker file which places those icons on the map. You'll need to set one or two environment variables so it knows where to look, but its very cool! Contributed by [Joao Pedro Goncalves][23], and updated by Hans.

Please install the [above geo_locator package][8] before trying to install weather.pl.

Last updated _02 May 2003_, Version 2.1.5: Updated wunderground.com parsing

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

|  ![partial screenshot][24] |
| Europe at dusk: it's sunny and slightly hazy with 14-26 degrees celsius (centigrade) in Berlin and mostly clear with 11-19 degree celsius in Moscow. |


***

### forecast

This is a perl script which gathers the current weather forecast for your location (home town) from [www.weather.com][25] (example: [Golden, CO, USA][26] or [Berlin, Germany][27] ) and writes a marker file which displays this forecast on your xplanet maps.

Please note that this script _may_ create a markerfile with absolute positions ("position=pixel") of more than 360. This is of course valid - your screen is likely wider than 360 pixels - but the stock xplanet 0.94 chokes on this. If you encounter problems, you have two possibilities:

1. If you are running Linux, download [the RPM file I provide below][18].
2. If you are running Windows, download [the xplanet distribution for Windows below][5].

Last updated _17 July 2003_, Version 1.2.5: 'title not found' bug fixed

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

|  ![partial screenshot][28] |
| Till Friday it will be cold and snowy, but will get drier and slightly warmer after Saturday. |


***

### earthq

This perl script downloads information about [the most recent earthquakes][29] and [bigger earthquakes of the last month][30] and writes them into a xplanet-style marker file, to be displayed on your maps. The idea and a reference implementation came from [Michael Dear][31], integrated, updated and rewritten to Perl5 by Hans.

Last updated _15 July 2003_, Version 2.1.7: filter out more errors in source data

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

If anybody out there has an artistic streak, I'd be really happy about nicer icons. I know I'm a crappy artist...

|  ![partial screenshot][32] |
| In south- and east Europe, we see 4 recent earthquakes: one of magnitude 4.4 near the Black Sea, on of magnitude 4.6 off the coast of Greece and two near Sicily of magnitude 4.5 and 5.9. The 5.9 earthquake happened on September 5th. |


***

### volcano

This perl script downloads information about [currently active volcanoes][33] and writes them into a xplanet-style marker file, to be displayed on your maps.

Last updated _05 May 2003_, Version 2.1.5: parsing improvements

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

* [volcano.pl][34] Copy into your xplanet directory
* [volcano.exe][35] Precompiled Windows executable
* [volcano_images.tar.gz][36] Some icons to denote volcanoes. By default we use volcano.png. If you don't like it, copy one of the others over it. Unpack in your xplanet directory (the icons should go into xplanet/images/)
* [volcano_images.zip][37] The same archive in ZIP format for Windows

|  ![partial screenshot][38] |
| Popocatepetl near Mexico City is active... |


***

### hurricane

This perl script downloads information about [tropical hurricanes][39] and writes them into a xplanet-style marker file, to be displayed on your maps. It can also generate a close-up inset of the area around the center of a storm close to you.

Last updated _15 July 2003_, Version 2.2.3: fix in inset name calculation - faster

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

* [hurricane.pl][40] Copy into your xplanet directory
* [hurricane.exe][41] Precompiled Windows executable
* [hurricane_data.tar.gz][42] Data files for that version. Unpack in your xplanet directory. About 3 MB.
* [hurricane_data.zip][43] The same archive in ZIP format for Windows
* [hurricane_images.tar.gz][44] 3 different iconsets. Each set comes with versions for the major hurricane types. By default we use the third set. If you don't like it, copy one of the others over it. Unpack in your xplanet directory (the icons should go into xplanet/images/)
* [hurricane_images.zip][45] The same archive in ZIP format for Windows

|  ![partial screenshot][46] |
| Off the eastern coast of the US, we see tropical storm Gustav speeding ahead with 46mph and tropical depression 07 going with 29mph. Green tracks show the actual, past, path of the hurricane, while blue tracks show its forecast positions.|

| ![partial screenshot][47] |
| An inset example: hurricane Lili shortly before crossing the western tip of Cuba. It is progressing to the North-West with 92 miles per hour. |


***

### visible-satellites

This perl script downloads information about satellites that will be visible to you during the night from [Heavens-Above.com][48]. The satellites will be displayed at all times, even when they are not visible. However, you can view how the trail of the satellites slowly moves towards your location, till at the prescribed time, it is above you.

Last updated _05 May 2003_, Version 0.8.2: more robust; code cleanup

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

|  ![partial screenshot][49]
| Off the south-eastern coast of Australia, satellites TRMM and STS-107 speed eastwards. At 5:47pm and 7:22pm we will be able to see TRMM from our home. At 5:33pm and 7:6pm, STS-107 will be visible to us. |


***

### xplanet-update

This script is meant to be run every 3 hours. It will

* Download the newest cloud map from any mirror
* Use this cloud map to create new day- and night-images containing clouds
* Download the newest satellite trajectories
* Execute any of Hans' scripts that are specified and installed, thereby renewing the various marker files and greatarc files

This script is a direct successor of the **xplanet.clouds.sh** part of the discontinued **xplanet-hans** package. But unlike xplanet.clouds.sh it
* Runs under Windows and Unix
* Uses the same configuration scheme as all the above scripts

Last updated _15 July 2003_, Version 0.9.7: Unix: overriding DISPLAY with GEOMETRY on top of script


***

### image-stream

This script is run continuously in the background. For a number of viewpoints (i.e. underneath the sun, on the morning terminator, above your home town) and projections (all projections xplanet can display) it continuously creates new xplanet images, using marker files created by any of the scripts above. Everything is of course configurable.

This script is a direct successor of the **xplanet.draw.sh** part of the discontinued **xplanet-hans** package. But unlike xplanet.draw.sh it
* Runs under Windows and Unix
* Uses the same configuration scheme as all the above scripts

Please install the [above geo_locator package][8] before trying to install image-stream. If you update image-stream, please also update geo_locator.

Last updated _15 July 2003_, Version 0.9.7: Unix: overriding DISPLAY with GEOMETRY on top of script


***

### moonphase

Using moonphase, your xplanet desktop shows the moon at its current position in its current phase. It also shows the dates when we have the next new moon, half moon and full moon.

Last updated _02 May 2003_, Version 0.8.1: new moonicons

Downloadable files: (Usage, documentation and ChangeLog inside the script file at the top)

| ![partial screenshot][50] |
| Today, on the 13th of February, the phase is between half- and full moon, increasing towards the full moon which will appear on the 17th. The next (decreasing) half moon will be on the 23rd. |


***

### xplanet Linux RPM

[xplanet-0.94-3.i386.rpm][51]: a binary xplanet package compiled under RedHat Linux 9.0 with freetype2 installed. Problems fixed:

* This might help if you encounter the problem that maps are produced, but no markers are written in them.
* Allows marker of the form

&gt; ` <x> <y> "text" position=pixel`

where `x` and `y` are above 360. Might be necessary for forecast.pl
* Satellites are drawn correctly. Thanks Gerrit Cap for the fix!

[xplanet-0.94-3.src.rpm][52]: The source RPM to this package, containing the patches.
[xplanet-0.94-3_8.0.i386.rpm][53]: The binary RPM, compiled under RedHat Linux 8.0.


***

### Windows information and fixed binary xplanet distribution

* Gerrit Cap provided a **Windows binary of xplanet**, in which the same problems as in the Linux RPM above are fixed: [xplanet-0.94-2.zip][54].
* You will need a version of xplanet.exe that has GIF image file support. xplanet-0.94a.zip (from [xplanet's homepage][3]) and the version above are known to work at least for NT and XP.
* If you have choosen to install the perl scripts (those .pl files), you need to have Perl installed. A good Perl distribution for Windows is [Active State's Active Perl][55]. But I also provide standalone Windows executables, so you don't need Perl anymore.
* The cookie file weather.pl needs must be in Netscape's format. This means cookie files from Internet Explorer do not work. You need cookie files from Netscape or Mozilla. I found Mozilla cookie files in
`C:WINDOWSApplication&nbsp;DataMozillaProfilesdefault***.sltcookies.txt`
or
`C:Documents&nbsp;and&nbsp;Settings<name>Application&nbsp;DataMozillaProfilesdefault***.sltcookies.txt`
or
`C:WINNTProfiles<name>Application&nbsp;DataMozillaProfilesdefault***.sltcookies.txt`


***

Please write with any suggestions to [Hans][56]

[1]: /web/peters_moon.jpg
[2]: http://acoustics.mines.edu/~hans/xplanet_images/current_1600x1200_peters_moon.jpg
[3]: http://xplanet.sourceforge.net
[4]: http://juad.ath.cx/flatplanet/
[5]: #windows-information-and-fixed-binary-xplanet-distribution
[6]: http://acoustics.mines.edu/pipermail/xplanet-scripts-news/
[7]: http://acoustics.mines.edu/mailman/listinfo/xplanet-scripts-news
[8]: #geo_locator-and-igeo
[9]: #weather
[10]: #forecast
[11]: #earthq
[12]: #volcano
[13]: #hurricane
[14]: #visible-satellites
[15]: #xplanet-update
[16]: #image-stream
[17]: #moonphase
[18]: #xplanet-linux-rpm
[19]: /GPL-license.txt
[20]: http://www.neurofractal.org
[21]: http://weather.yahoo.com
[22]: http://www.wunderground.com
[23]: mailto:joaop%40co.sapo.pt
[24]: /web/ex_weather.jpg
[25]: http://www.weather.com
[26]: http://www.weather.com/weather/print/80403
[27]: http://www.weather.com/outlook/travel/print/GMXX0007
[28]: /web/ex_forecast.jpg
[29]: http://neic.usgs.gov/neis/bulletin/bulletin.html
[30]: http://neic.usgs.gov/neis/qed/qed.html
[31]: http://www.wizabit.eclipse.co.uk/xplanet/
[32]: /web/ex_earthq.jpg
[33]: http://www.volcano.si.edu/gvp/usgs/
[34]: http://hans.ecke.ws/volcano.pl
[35]: http://hans.ecke.ws/volcano.exe
[36]: http://hans.ecke.ws/volcano_images.tar.gz
[37]: http://hans.ecke.ws/volcano_images.zip
[38]: /web/ex_volcano.jpg
[39]: http://www.solar.ifa.hawaii.edu/Tropical
[40]: /hurricane.pl
[41]: http://hans.ecke.ws/hurricane.exe
[42]: http://hans.ecke.ws/hurricane_data.tar.gz
[43]: http://hans.ecke.ws/hurricane_data.zip
[44]: http://hans.ecke.ws/hurricane_images.tar.gz
[45]: http://hans.ecke.ws/hurricane_images.zip
[46]: /web/ex_hurricane.jpg
[47]: /web/ex_hurricane_inset.jpg
[48]: http://www.heavens-above.com
[49]: /web/ex_visible-satellites.jpg
[50]: /web/ex_moonphase.jpg
[51]: http://hans.ecke.ws/xplanet-0.94-3.i386.rpm
[52]: http://hans.ecke.ws/xplanet-0.94-3.src.rpm
[53]: http://hans.ecke.ws/xplanet-0.94-3_8.0.i386.rpm
[54]: http://hans.ecke.ws/xplanet-0.94-2.zip
[55]: http://www.activestate.com/Products/ActivePerl/
[56]: mailto:hans(at)ecke(dot)ws

