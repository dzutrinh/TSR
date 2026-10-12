{*********************************}
{ DUMPVIEW.PAS                    }
{---------------------------------}
{ Dump image viewer program       }
{ Written by Nguyen Dac Dzu Trinh }
{---------------------------------}
{ TURBO/BORLAND PASCAL version    }
{*********************************}

{$F+,X+,E-,N-}
{$M 8192, 8192, 163840}

uses
	crt;

type
        { define a pointer type for easier accessing }
	RASTER_TYPE	= array[0..63999] of byte;
	RASTER_PTR	= ^RASTER_TYPE;

        { simple palette type }
        DAC_REG		= record
        	r, g, b	: byte;
        end;

        PALETTE_TYPE	= array[0..255] of DAC_REG;

const
        MAX_WIDTH	= 320;			{ screen width }
        MAX_HEIGHT	= 200;			{ screen height }

        { pointer to VIDEO RAM }
        VIDEO_BUFFER	: RASTER_PTR = PTR($A000, 0);

procedure	copy_right;	assembler;
asm
	jmp	@SKIP
	db	0Dh, 0Ah
	db	"+---------------------------------+", 0Dh, 0Ah
	db	"|    DUMP IMAGE VIEWER PROGRAM    |", 0Dh, 0Ah
	db	"| Written by Nguyen Dac Dzu Trinh |", 0Dh, 0Ah
	db	"+---------------------------------+", 0Dh, 0Ah
	db	0Dh, 0Ah
@SKIP:
end;

{ initialize graphic mode }
procedure       init_graph;     assembler;
asm
        mov	ax, 0013h			{ MCGA 320x200, 256 colours mode }
        int	10h
end;

{ close graphic mode }
procedure	done_graph;	assembler;
asm
        mov	ax, 0003h			{ EGA/VGA text mode }
        int	10h
end;

{ routine to set a DAC palette }
procedure       set_palette(var pal);	assembler;
asm
	les	di, pal                 	{ ES:DX = palette address }
        mov	dx, di
	mov	ax, 1012h			{ VGA set palette func. }
        xor	bx, bx				{ process entire palette }
        mov	cx, 256
        int	10h
end;

{ function to read a DUMP image }
function	read_dump(filename: string; var buffer: RASTER_PTR; var pal: PALETTE_TYPE): boolean;
var
	f	: FILE;
begin
	assign(f, filename);
        {$I-}
        reset(f, 1);
	{$I+}
        if ioresult <> 0 then
         begin
          read_dump := FALSE;
          exit;
         end;

        { reading image data }
        blockread(f, buffer^, MAX_WIDTH * MAX_HEIGHT);
        { reading palette data }
        blockread(f, pal, sizeof(PALETTE_TYPE));

        close(f);
        read_dump := TRUE;
end;

{ display an image buffer with a special effect }
procedure	leak_buffer(var buffer: RASTER_PTR);
var
	i, j,
	off	: word;
begin
	off	:= MAX_WIDTH * (MAX_HEIGHT - 1);
        for i := MAX_HEIGHT - 1 downto 0 do		{ bottom up }
         begin
          for j := 0 to i do				{ top-down }
           move(buffer^[off], VIDEO_BUFFER^[MAX_WIDTH * j], MAX_WIDTH);
          dec(off, MAX_WIDTH);
          delay(2);
         end;
end;

{ draw a filled box }
procedure	bar(x1, y1, x2, y2: word; color: byte);
var
	i, x,
	deltaX, deltaY,
	screenofs	: word;
begin
	deltaX	:= abs(x2 - x1);
        deltaY	:= abs(y2 - y1);
        screenofs := (y1 shl 8) + (y1 shl 6) + x1;
        for i := 0 to deltaY do
         begin
          for x := 0 to deltaX do
           mem[$A000:screenofs + x] := color;
          inc(screenofs, MAX_WIDTH);
         end;
end;

{ show current palette }
procedure	display_palette;
var
	x, y,
        color	: byte;
begin
	color	:= 0;
        for y := 0 to 15 do
         for x := 0 to 15 do
          begin
           bar(x * 10 + 80,
	       y * 6 + 104,
	       8 + x * 10 + 80,
	       4 + y * 6 + 104,
	       color);
           inc(color);
          end;
end;

var
	buffer	: RASTER_PTR;
	palette	: PALETTE_TYPE;
        switch,
	filename: string;

begin
	copy_right;

        if paramcount = 0 then
	 begin
          writeln('  Usage: DUMPVIEW.EXE <dmpfile>[.DMP] [-p]'#13#10+
          	  #13#10+
                  'Example: dumpview amber.dmp'#13#10+
	  	  'Use option -p if you want to show the image palette.');
	  exit;
         end;

        filename := paramstr(1);
        switch	 := paramstr(2);

	if pos('.', filename) = 0 then
         filename := filename + '.dmp';

	init_graph;

        { allocate image buffer }
	getmem(buffer, MAX_WIDTH * MAX_HEIGHT);

        { load specified dump image through command line }
        if not read_dump(filename, buffer, palette) then
	 begin
          freemem(buffer, MAX_WIDTH * MAX_HEIGHT);
          done_graph;
          exit;
	 end;

        set_palette(palette);			{ set the image palette }

        if switch = '-p' then
         display_palette
        else
 	 leak_buffer(buffer);                    { show image buffer }

        readkey;

        { deallocate image buffer }
        freemem(buffer, MAX_WIDTH * MAX_HEIGHT);
	done_graph;
end.

