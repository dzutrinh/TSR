# TSR utilities for DOS
These are the utilities I coded long ago when I still in university, following the course of Assembly Programming. I thought they were completely lost in the old diskettes but recently found out I have a backup in one of the old HDDs.

## CAP.COM
- VGA Image capture for DOS.
- This program supports mode 13h (not mode X) and text modes (any rows, the page shown).
- Run this program to install it onto memory. Hit F12 to take 
a screenshot. Screenshots will be saved at current drive and folder under the names SNAP0000.CAP, SNAP0001.CAP, ... (the first unused).
- Rerun this program to remove it from memory.

## PALSHOT.COM
- VGA/MCGA palette capture for DOS.
- Run this program to install it onto memory. Hit F12 to take 
a snapshot of current video palette, saved at the current drive and folder under the name PALSHOT.PAL: the 256 DAC colors (768 bytes, red/green/blue each).
- Rerun this program to remove it from memory.

## CLOCK.COM
- Display a ticking clock at the top right corner of the screen, in text modes.
- Rerun this program to remove it from memory.

## Viewers
- `CAPVIEW <file>[.CAP]`: shows a CAP.COM capture. Hold Space to see its palette, Esc quits.
- `DUMPVIEW <file>[.DMP] [-p]`: shows a 320x200 dump (64000 bytes of picture, then 768 of palette, the layout of a mode 13h capture); `-p` shows its palette instead. Any key quits.
- `PAL2PAS <file>[.PAL] <file>[.INC]`: turns a 768-byte palette (PALSHOT.PAL) into a Pascal include file.

## Notes
- CAP and PALSHOT need DOS 3.1 or later and a VGA or MCGA.
- The file is written a moment after F12, once DOS is free. A failed save leaves no file.
- All 2 drivers can be installed at a time; F12 makes each of CAP and PALSHOT installed save its file. A driver can't be removed while another program has hooked its interrupts since: remove them in the reverse order.

## Building
- `MAKE` builds the drivers (TASM, TLINK) and the 3 utilities (Borland Pascal 7, `BPC`); `MAKE clean` clears out all binaries.

by Trinh D.D. Nguyen
