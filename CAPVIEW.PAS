uses
	dos, crt;

const
	SIZE_GRAPH	= 64768;
        SIZE_TEXT	= 4768;

type
	COLOR_REG = record
        	red,
		green,
		blue	: byte;
        end;

        Palette	= array[0..255] of COLOR_REG;

procedure	SetPalette(var pal);
var
	r	: Registers;
begin
	r.ax	:= $1012;
	r.bx	:= 0;
        r.cx	:= 256;
        r.es	:= SEG(Pal);
        r.dx	:= OFS(Pal);
        intr($10, r);
end;

procedure	Bar(x1, y1, x2, y2: Word; Color: Byte);
var
	i, x,
	DeltaX, DeltaY,
	ScreenOfs	: Word;
begin
	DeltaX	:= abs(x2 - x1);
        DeltaY	:= abs(y2 - y1);
        ScreenOfs := (y1 shl 8) + (y1 shl 6) + x1;
        for i := 0 to DeltaY do
         begin
          for x := 0 to DeltaX do
           mem[$A000:ScreenOfs + x] := Color;
          inc(ScreenOfs, 320);
         end;
end;

procedure	GraphPal;
var
	x, y,
        Color	: Byte;

begin
	Color	:= 0;
        for y := 0 to 15 do
         for x := 0 to 15 do
          begin
           Bar(x * 10 + 80, y * 6 + 104, 8 + x * 10 + 80, 4 + y * 6 + 104, Color);
           inc(Color);
          end;
end;

procedure	TextPal;
var
        i,
	color	: byte;
begin
	color := $00;
        for i := 1 to 16 do
         begin
          gotoxy(1, i);
          textattr := $0F;
          write('Color ',i:2,' : ');
          textattr := color;
          write('лллл');
          inc(color);
         end;
end;

procedure	init_graphic;	assembler;
asm
	mov	ax, 0013h
        int	10h
end;

{ 80 or 40 columns; 28 rows: 8x14 font, 43: 350 lines and 8x8, 50: 8x8 }
procedure	init_text(cols, rows: word);	assembler;
asm
	cmp	rows, 43
	jne	@MODE
	mov	ax, 1201h			{ 350 scan lines }
	mov	bl, 30h
	int	10h
@MODE:
        mov	ax, 0003h			{ switch to text mode }
	cmp	cols, 40
	jne	@SET
	mov	ax, 0001h
@SET:
        int	10h
	cmp	rows, 28
	jne	@NOT28
	mov	ax, 1111h			{ 8x14 font }
	xor	bl, bl
	int	10h
@NOT28:
	cmp	rows, 43
	je	@SMALL
	cmp	rows, 50
	jne	@FONT
@SMALL:
	mov	ax, 1112h			{ 8x8 font }
	xor	bl, bl
	int	10h
@FONT:
        mov	ax, 1003h			{ set blinking off }
	xor	bl, bl
	int	10h
	mov	ah, 01h				{ hide cursor }
       	mov	cx, 2020h
       	int	10h
end;

{ back to 400 scan lines, then 80x25 }
procedure	done_text;	assembler;
asm
	mov	ax, 1202h
	mov	bl, 30h
	int	10h
	mov	ax, 0003h
	int	10h
end;

{ a text capture's columns and rows from its file size (screen data and
  768 bytes of palette); FALSE: not one CAPVIEW can show }
function	text_size(fsize: longint; var cols, rows: word): boolean;
var
	n	: longint;
begin
	text_size := FALSE;
	n := fsize - sizeof(Palette);
	if n <= 0 then exit;
	if n = 4000 then
	 begin
	  cols := 80;
	  rows := 25;
	 end
	else if n mod 160 = 0 then
	 begin
	  cols := 80;
	  rows := n div 160;
	 end
	else if n mod 80 = 0 then
	 begin
	  cols := 40;
	  rows := n div 80;
	 end
	else exit;
	text_size := (rows = 25) or ((cols = 80) and ((rows = 28) or (rows = 43) or (rows = 50)));
end;

function	getvmode: byte;	assembler;
asm
	mov	ah, 0fh
        int	10h
end;

procedure	disable;	assembler;
asm
	cli
end;

procedure	enable;	assembler;
asm
	sti
end;

procedure	CAPLoad(filename: string);
var
	buffer	: pointer;
        pal	: Palette;
        capf	: file;
	fsize	: longint;
	vmode	: byte;
	size,
	cols,
	rows	: word;

begin
        if pos('.', filename) = 0 then
         filename := filename + '.CAP';

        fillchar(pal, sizeof(pal), 0);
	assign(capf, filename);
        {$I-}
        reset(capf, 1);
        {$I+}
        if IOresult <> 0 then
         begin
          writeln('Unable to open file "'+filename+'".');
          halt;
         end;

        fsize := filesize(capf);
        size := fsize - sizeof(pal);

        if fsize = SIZE_GRAPH then
	 begin
          init_graphic;
          getmem(buffer, 64000);
          blockread(capf, buffer^, 64000);
          blockread(capf, pal, sizeof(pal));
          setpalette(pal);
          move(buffer^, PTR($A000, 0)^, 64000);
         end
        else
         if text_size(fsize, cols, rows) then
	  begin
           init_text(cols, rows);
           getmem(buffer, size);
           blockread(capf, buffer^, size);
           blockread(capf, pal, sizeof(pal));
           setpalette(pal);
           move(buffer^, PTR($B800, 0)^, size);
          end
         else
          begin
           close(capf);
           writeln('"'+filename+'" is not a CAP file CAPVIEW can show.');
           halt;
          end;

        vmode	:= getvmode;

        repeat
         if port[$60] = 57 then
          begin
           if vmode = $13 then
            begin
             GraphPal;
             repeat
              disable;
              mem[$0000:$041A] := mem[$0000:$041C];
              enable;
             until port[$60] = 57 or 128;
             move(buffer^, PTR($A000,0)^, 64000);
            end
           else
            begin
             TextPal;
             repeat
              disable;
              mem[$0000:$041A] := mem[$0000:$041C];
              enable;
             until port[$60] = 57 or 128;
             move(buffer^, PTR($B800,0)^, size);
            end;
          end;
        until port[$60] = 1;

        close(capf);
	freemem(buffer, size);
end;

begin
        if paramcount = 0 then
	 writeln('CAPVIEW.EXE: CAP file viewer - version 1.0'#13#10+
	 	 'Written by Nguyen Dac Dzu Trinh - (c) 1998 by ODYSSEY software'#13#10+
         	 #13#10+
	 	 'Usage: CAPVIEW <CAPFile>[.CAP]'#13#10+
		 '       CAPFile is an image captured with CAP.COM')
        else
         begin
          CAPLoad(ParamStr(1));
          done_text;
          textmode(3);
         end;
end.
