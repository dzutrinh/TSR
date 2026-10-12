type
	COLOR_REG = record
        	red,
                green,
		blue	: byte;
        end;

        Palette = array[0..255] of COLOR_REG;

var
	f	: file of Palette;
        pasf	: text;
	pal	: Palette;
        i	: word;
	source,
        dest	: string;

begin
        writeln('PAL2PAS: Convert from Palette file type to Pascal file type'#13#10+
	  	'Written by Nguyen Dac Dzu Trinh - (c) 1998 by ODYSSEY software'#13#10);

        if paramcount <> 2 then
         begin
	  writeln('  Usage: PAL2PAS <PALFile>[.PAL] <PASFile>[.INC]'#13#10+
		  'Whereas: PALFile = Palette file (always 768 bytes)'#13#10+
		  '         PASFile = Pascal include file.'#13#10);
	  halt;
         end;

        source	:= paramstr(1);
        dest	:= paramstr(2);

        if pos('.', source) = 0 then source := source + '.PAL';
        if pos('.', dest) = 0 then dest := dest + '.INC';

	assign(f, source);
        {$I-}
        reset(f);
        {$I+}
        if IOresult <> 0 then
         begin
          writeln('Unable to open source file: "'+source+'".');
          halt;
         end;

	assign(pasf, dest);
        {$I-}
        rewrite(pasf);
        {$I+}
        if IOresult <> 0 then
         begin
          writeln('Unable to creat target file: "'+dest+'".');
          halt;
         end;

	writeln('Converting from '+source+' to '+dest+'...');

        read(f, pal);
        writeln(pasf, 'type	__COLOR_REG = record'#13#10+
		      '		red, green, blue: byte;'#13#10+
		      '	end;'#13#10+
		      #13#10+
		      '	__Palette = array[0..255] of __COLOR_REG;'#13#10);
        writeln(pasf, 'const	PAL: __Palette = '#13#10+
		      '		(');

	for i := 0 to 254 do
         begin
          writeln(pasf, '		 ',
	  		'(red:',pal[i].red:3,
	  		'; green:',pal[i].green:3,
			'; blue:',pal[i].blue:3,'),');
         end;
         writeln(pasf, '		 ',
	  	       '(red:',pal[255].red:3,
	  	       '; green:',pal[255].green:3,
		       '; blue:',pal[255].blue:3,')');
        writeln(pasf, '		);');

        close(f);
        close(pasf);
	writeln('Convert complete!.');
end.
