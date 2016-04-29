//FileCopy function taken from http://wiki.freepascal.org/File_Handling_In_Pascal#FileCopy
//LazUtils must be added as a project dependency
//This webpage was very useful for listing contents of a folder:
//http://lazplanet.blogspot.co.uk/2013/07/how-to-list-files-in-folder.html
//And, as usual, the official Free Pascal documentation was extremely useful
program DownloadPlaylist;

{$mode objfpc}{$H+}

uses
  Classes,    //Use addToLog procedure
  StrUtils,   //validate when user inputs data for setiTunesFolder using a new procedure - make sure there are slashes, presence check, all slashes same type, remove slash at end if there is one
  SysUtils,
  DownloadPlaylistObjects,
  Crt,
  FileUtil;

const
  playlistName = 'James PC';
  iTunesFolderLocation = 'Z:\Music\iTunes';
  destinationFolderLocation = 'D:\Music';
  useLog = False;
  logFileAddress = destinationFolderLocation + '\log.txt'

  //If this is set to true, the program will create a temporary copy of the iTunes Music Library.xml file
  //in the destination directory to speed up indexing if syncing from a network drive to a local drive
  useiTunesXMLcopy = True;

var
  libraryFile, logFile: TextFile;
  tracks: array of tTrack;
  noOfTracks, i, i2: integer;
  src: tSrc;
  dest: tDest;
  currentline: string;
  trackIDfound: Boolean;

procedure finish;
begin
  addToLog('Sync complete', 0);
  closefile(logFile);
  ClrScr;
  writeln('Sync complete (press enter to quit)');
  readln;
end;

procedure addToLog(message: string; severity: integer);//0=log entry, 1=warning,
begin                                                  //2=error
  case severity of
    0: begin
         if useLog then
           writeln('Info: ' + message, logFile);
       end;
    1: begin
         if useLog then
           writeln('Warning: ' + message, logFile);
         ClrScr;
         gotoXY(1,1);
         write('Warning: ' + message);
         sleep(2000);
       end;
    2: begin
         if useLog then
           writeln('Error: ' + message, logFile);
         ClrScr;
         gotoXY(1,1);
         write('Error: ' + message + ' (press enter to dismiss)');
         readln;
         closeFile(logFile);
         halt;
       end;
  end;
end;

function FileCopy(Source, Target: string): boolean;
// Copies source to target; overwrites target.
// Caches entire file content in memory.
// Returns true if succeeded; false if failed.
var
  MemBuffer: TMemoryStream;
begin
  result := false;
  MemBuffer := TMemoryStream.Create;
  try
    MemBuffer.LoadFromFile(Source);
    MemBuffer.SaveToFile(Target);
    result := true
  except
    addToLog('Could not copy file', 2)
    //swallow exception; function result is false by default
  end;
  // Clean up
  MemBuffer.Free
end;

function expandCharCodes(input: string): string;
begin
  try
    result := input;
    while (Pos('%', result) <> 0) do
    begin
      result := leftstr(result, Pos('%', result) - 1) + chr(Hex2Dec(MidStr(result, Pos('%', result) + 1, 2))) + rightstr(result, length(result) - (Pos('%', result) + 2));
    end;
    while (pos('&#', result) <> 0) and (pos(';', result) = pos('&#', result) + 4) do
    begin
      result := leftstr(result, pos('&#', result) - 1) + chr(strtoint(midStr(result, pos('&#', result) + 2, 2))) + rightstr(result, length(result) - (pos('&#', result) + 4));
    end;
  except
    addToLog('Could not convert character codes in: ' + input, 1);
  end;
end;

procedure openLibraryFileForRead(location : string);
begin
  try
    assignfile(libraryFile, location);
    reset(libraryFile);
  except
    addToLog('Could not open iTunes Music Library.xml file', 2);
  end;
end;

procedure createTrack;
begin
  inc(noOfTracks);
  setLength(tracks, noOfTracks);
  tracks[noOfTracks - 1] := tTrack.Create;
end;

function seekTo(phrase: string): Boolean; overload;
begin                           //^returns whether it was successful
  try
    while not ((Pos(phrase, currentLine) <> 0) or eof(libraryFile)) do
    begin           //whilst phrase isn't in the current line
      readln(libraryFile, currentLine);
    end;
    if (Pos(phrase, currentLine) = 0) then
    begin
      result := False   //if it searched twice but still didn't find it
    end                 //(twice because the program might have started halfway
    else                //through the file)
    begin
      result := True;
    end;
  except
    result := False
  end;
end;

function seekTo(phrase: string; endSearch: string): Boolean; overload;
var      //end search if this is found^             //^returns whether it was successful
  count: smallInt;
begin
  try
    count := 0;
    repeat
      while not ((Pos(phrase, currentLine) <> 0) or  //until it finds phrase or endSearch
                (Pos(endSearch, currentLine) <> 0) or eof(libraryFile)) do
      begin                                          //or the end of the file
        readln(libraryFile, currentLine);
      end;
      inc(count);
    until (count = 2) or ((Pos(phrase, currentLine) <> 0) or
          (Pos(endSearch, currentLine) <> 0));
    if (Pos(phrase, currentLine) = 0) or (Pos(endSearch, currentLine) <> 0) then
      result := False   //if it searched twice but still didn't find it (twice
    else result := True; //because the program might have started halfway
  except                 //through the file) or it found endSearch
    result := False
  end;
end;

function findIntIn(input: string): integer;
begin
  try
    result := strtoint(MidStr(input, Pos('<integer>', input) + 9, (Pos('</integer>', input) - (Pos('<integer>', input))) - 9));
  except
    result := -1;
  end;
end;

function findStrIn(input: string): string;
begin
  try
    result := MidStr(input, Pos('<string>', input) + 8, (Pos('</string>', input) - (Pos('<string>', input))) - 8);
  except
    result := #1;
  end;
end;

function translateFileAddress(inputFile: string): string;
var
  position: integer;
begin
  try
    position := length('/iTunes/');      //position is a position from the right here
    while Pos('/iTunes/', rightstr(inputFile, position)) = 0 do
      inc(position);   //find the last iTunes directory in the file address - this will be the iTunes folder
    result := rightstr(inputFile, position - 7);
    //make sure correct slash is used
    for position := 1 to length(result) do   //position is a position from the left here
    begin
      if ((result[position] = '/') or (result[position] = '\')) and (not (result[position] = src.getSlash)) then
        result[position] := src.getSlash;
    end;
    result := src.getiTunesFolder + result;
  except
    addToLog('Could not translate a source file address to a destination file address', 2);
  end;
end;

function replaceSlash(input: string; changeFor: char): string;
var
  position: integer;
begin
  try
    result := input;
    for position := 1 to length(result) do
      if (result[position] = '\') or (result[position] = '/') then result[position] := changeFor;
  except
    addToLog('There was an error replacing a slash in the filename', 2);
  end;
end;

procedure removeUnwanted;
var
  foldersCreated: textFile;          //folders are organised by album
  count, count2, noOfMusicFolders, isDirectoryPopulated: integer;
  musicFolders: array of string; //used to store names of folders which foldersCreated.txt indicates are being used for storing music
  folderUnwanted: boolean;
  fileInfo: TSearchRec;
begin
  try
    //---READ INTO FOLDERSCREATED ARRAY---\\
    noOfMusicFolders := 0;      //If we have a foldersCreated.txt file from a previous sync
    if fileexists(dest.getFolder + dest.getSlash + 'foldersCreated.txt') then
    begin
      assignFile(foldersCreated, dest.getFolder + dest.getSlash + 'foldersCreated.txt');
      reset(foldersCreated);
      addToLog('Updating directory structure and removing unwanted items...', 0)
      gotoXY(1,1);
      ClrEol;
      write('Updating directory structure and removing unwanted items...');
      while not eof(foldersCreated) do
      begin
        gotoXY(1,2);
        ClrEol;
        write(inttostr(noOfMusicFolders));
        inc(noOfMusicFolders);                                                                     //BUG:MIGHT NOT BE DELETING FROM musicFolders ARRAY IF UNWANTED
        setLength(musicFolders, noOfMusicFolders);                                                 //BUG:DELETES EVEN IF DIRECTORY IS IN PLAYLIST
        readln(foldersCreated, musicFolders[noOfMusicFolders - 1]);                                //BUG:STILL DELETING DESPITE SETTING FOLDERUNWANTED TO FALSE
        folderUnwanted := True;
        count := 0;
        //---DETERMINE IF CURRENT FOLDER IS WANTED---\\
        repeat
          if (tracks[count].getAlbum = musicFolders[noOfMusicFolders - 1]) then
          begin
            folderUnwanted := False;
          end;
          inc(count)
        until ((count >= noOfMusicFolders) or (not (folderUnwanted)));
        //---IF UNWANTED, DELETE---\\
        if folderUnwanted then
        begin
          deleteDirectory(dest.getFolder + dest.getSlash + musicFolders[noOfMusicFolders - 1], False);
          dec(noOfMusicFolders);
          setLength(musicFolders, noOfMusicFolders);
        end
        else
        begin
          //---DELETE UNWANTED SONGS---\\\             //if it managed to find a file in the current folder and output its information to fileInfo
          if findFirst(dest.getFolder + dest.getSlash + musicFolders[noOfMusicfolders - 1] + dest.getSlash + '*', faAnyFile, fileInfo) = 0 then
          begin
            isDirectoryPopulated := 0;
            while ((fileInfo.Name = '.') or (fileInfo.Name = '..')) and (isDirectoryPopulated = 0) do //ignore '.' and '..' since they are symbolic links that appear in every directory and cannot be deleted
              isDirectoryPopulated := findNext(fileInfo);
            while isDirectoryPopulated = 0 do //whilst there are fies in the directory to be scanned
            begin
              count2:=0;       //scroll through tracks until a match in the playlist is found for the file, or the list of tracks is exhausted
              while not ((Tracks[count2].getDestAddress = dest.getFolder + dest.getSlash + musicFolders[noOfMusicFolders - 1] + dest.getSlash + fileInfo.Name) or (count2 >= noOfTracks - 1)) do
                inc(count2);
              //if it did not find a track which matches the file found, then delete
              if not (Tracks[count2].getDestAddress = dest.getFolder + dest.getSlash + musicFolders[noOfMusicFolders - 1] + dest.getSlash + fileInfo.Name) then
                if not deleteFile(dest.getFolder + dest.getSlash + musicFolders[noOfMusicFolders - 1] + dest.getSlash + fileInfo.Name) then
                  addToLog('Could not delete unwanted song', 2);
              isDirectoryPopulated := findNext(fileInfo);
            end;
            findClose(fileInfo);
          end;
        end;
      end;
      closefile(foldersCreated);
    end;
    //---IF A DIRECTORY IS NEEDED WHICH DOES NOT EXIST, CREATE IT---\\
    for count := 0 to noOfTracks - 1 do
    begin
      if not directoryExists(dest.getFolder + dest.getSlash + tracks[count].getAlbum) then
      begin
        if createDir(dest.getFolder + dest.getSlash + tracks[count].getAlbum) then
        begin
          inc(noOfMusicFolders);
          setLength(musicFolders, noOfMusicFolders);
          musicFolders[noOfMusicFolders - 1] := tracks[count].getAlbum;
        end;
      end;
    end;
    //---IF foldersCreated.txt EXISTS, ATTEMPT TO DELETE IT---\\
    {if fileexists(dest.getFolder + dest.getSlash + 'foldersCreated.txt') and (not deleteFile(dest.getFolder + dest.getSlash + 'foldersCreated.txt')) then
      addToLog('Could not delete old foldersCreated.txt', 2);}
    //---WRITE TO foldersCreated.txt---\\\
    assignFile(foldersCreated, dest.getFolder + dest.getSlash + 'foldersCreated.txt');
    rewrite(foldersCreated);
    if noOfMusicFolders > 0 then
    begin
      for count := 0 to noOfMusicFolders - 1 do
      begin
        writeln(foldersCreated, musicFolders[count]);
      end;
    end;
    closeFile(foldersCreated);
  except
    addToLog('Could not remove obsolete directories or create new foldersCreated.txt file', 2);
  end;
  addToLog('Finished updating directory structure and removing unwanted items', 0);
end;

procedure initialise;
begin
  if useLog then
  begin
    assignfile(logFile, logFileAddress);
    rewrite(logFile);
  end;
  addToLog('Initialising...', 0);
  try
    write('Initialising...');
    noOfTracks := 0;
    src := tSrc.Create;
    dest := tDest.Create;
    src.setiTunesFolder(iTunesFolderLocation);
    dest.setfolder(destinationFolderLocation);
    if useiTunesXMLcopy then
    begin
      addToLog('Making temporary copy of iTunes Music Library.xml...', 0);
      gotoXY(1,1);
      ClrEol;
      write('Making temporary copy of iTunes Music Library.xml...');
      fileCopy(src.getiTunesFolder + src.getSlash + 'iTunes Music Library.xml', dest.getFolder + dest.getSlash + 'iTunes Music Library.xml.temp');
      openLibraryFileForRead(dest.getFolder + dest.getSlash + 'iTunes Music Library.xml.temp');
    end
    else
      openLibraryFileForRead(src.getiTunesFolder + src.getSlash + 'iTunes Music Library.xml');
    addToLog('Initialised', 0);
  except
    addToLog('Could not initialise', 2);
  end;
end;

procedure findPlaylist;
begin
  try
    gotoXY(1, 1);
    ClrEol;
    write('Finding playlist...');
    addToLog('Finding playlist...', 0);
    if not seekTo('<key>Playlists</key>') then //if seeking to Playlists section was unsuccessful
    begin
      addToLog('Failed to find playlists section in iTunes Music Library.xml', 2);
    end;
    if not seekTo('<key>Name</key><string>' + playlistName + '</string>', '</plist>') then  //if seekTo was unsuccessful
    begin
      addToLog('Failed to find playlist in iTunes Music Library.xml', 2);
    end;
    addToLog('Playlist found', 0);
  except
    addToLog('An unknown error occurred whilst trying to find the playlist in iTunes Music Library.xml', 2);
  end;
end;

procedure retrieveTrackIDs;
begin
  try
    gotoXY(1, 1);
    ClrEol;
    write('Retrieving Track IDs from playlist...');
    addToLog('Retrieving Track IDs from playlist...', 0);
    while seekTo('Track ID', '</array>') do//seek to track IDs before array end
    begin
      i := findIntIn(currentLine);
      if (i = -1) then
        addToLog('Failed to find a track ID', 2)
      else
      begin
        createTrack;
        tracks[noOfTracks - 1].setID(i);
      end;
      readln(libraryFile, currentLine); //read the next line so seekTo doesn't get stuck on the same line
    end;
    if (noOfTracks = 0) then
      addToLog('No Track IDs were found in the playlist', 2);
    addToLog('Retrieved Track IDs', 0);
  except
    addToLog('An unknown error occurred when retrieving track IDs from the playlist', 2);
  end;
end;

procedure gatherTrackIDinfo;
var
  functionResult : integer;
begin
  try
    gotoXY(1, 1);
    ClrEol;
    write('Gathering information about track IDs...');
    addToLog('Gathering information about track IDs...', 0);
    reset(libraryFile);
    if (noOfTracks >= 1) then
    begin
      for i := 0 to noOfTracks - 1 do
      begin
        gotoXY(1, 2);
        ClrEol;
        write(inttostr(i + 1) + '/' + inttostr(noOfTracks));
        i2 := 0;
        repeat
          inc(i2);
          trackIDfound := seekTo('<key>Track ID</key><integer>' + inttostr(tracks[i].getID) + '</integer>', '<key>Playlists</key>');
          if trackIDfound then //search for the track ID but stop searching if it has reached the playlists section
          begin
            try
              if seekTo('<key>Track Number</key>', '<key>Track Count</key>') then //if it managed to seek to the track number without reaching the next piece of data
              begin
                functionResult := findIntIn(currentLine);
                if functionResult = -1 then
                  addToLog('Did not successfully find a track ID', 2);
                else
                  tracks[i].setTrackNo(functionResult);
              end
              else
              begin
                addToLog('Track number of song could not be found', 2);
              end;

              if seekTo('<key>Name</key>', '<key>Artist</key>') then //if it managed to seek to the name without reaching the next piece of data
              begin
                functionResult := findStrIn(currentLine);
                if (functionResult = -1) then
                  addToLog('Did not successfully find a track name', 2)
                else
                  tracks[i].setTitle(replaceSlash(expandCharCodes(functionResult), '_'));
              end
              else
                addToLog('Name of song could not be found', 2);

              if seekTo('<key>Album</key>', '<key>Genre</key>') then //if it managed to seek to the album without reaching the next piece of data
              begin
                functionResult := findStrIn(currentLine);
                if (functionResult = -1) then
                  addToLog('Did not successfully find an album name', 2)
                else
                  tracks[i].setAlbum(replaceSlash(expandCharCodes(functionResult), '_'));
              end
              else
                addToLog('Album of song could not be found', 2);

              if seekTo('<key>Location</key>', '</dict>') then //if it managed to seek to the location without reaching the end of the track information
              begin
                functionResult := findStrIn(currentLine);
                if (functionResult = -1) then
                  addToLog('Did not successfully find a track source address', 2)
                else
                  tracks[i].setSrcAddress(translateFileAddress(expandCharCodes(functionResult)));
              end
              else
                addToLog('Source address of song could not be found', 2);
            except
                addToLog('Information about track(s) could not be retrieved', 2);
            end;
          end
          else
          begin
            reset(libraryFile);
            readln(libraryFile, currentLine); //so that seekTo does not analyse the last value that currentLine was set to
          end;
        until (trackIDfound) or (i2 = 2);
        if not trackIDfound then
          addToLog('A track ID from the playlist could not be found in the iTunes' +
                   ' library', 2);
        tracks[i].determineDestAddress(dest.getFolder, dest.getSlash);
      end;
    end;
    addToLog('Finished gathering information about track IDs', 0);
  except
    addToLog('An unknown error occurred whilst gathering information about track IDs', 2);
  end;
end;

procedure closeLibraryFile;
begin
  try
    addToLog('Closing library file...', 0);
    closeFile(libraryFile);
    if useiTunesXMLcopy then
      if not deleteFile(dest.getFolder + dest.getSlash + 'iTunes Music Library.xml.temp') then
        addToLog('Could not delete temporary copy of iTunes Music Library.xml', 2);
    addToLog('Closed library file', 0);
  except
    addToLog('An unknown error occurred whilst closing/deleting a temporary copy of the iTunes media library.xml file', 2)
  end;
end;

procedure copyFiles;
begin
  try
    addToLog('Copying files...', 0);
    gotoXY(1,1);
    ClrEol;
    write('Copying files...');
    for i := 0 to noOfTracks - 1 do
    begin
      gotoXY(1,2);
      ClrEol;
      write(inttostr(i + 1) + '/' + inttostr(noOfTracks));
      if not fileExists(tracks[i].getDestAddress) then
      begin
        addToLog('Copying track ' + inttostr(i + 1) + '/' + inttostr(noOfTracks), 0);
        fileCopy(tracks[i].getSrcAddress, tracks[i].getDestAddress);
      end;
    end;
    addToLog('Copied files', 0);
  except
    addToLog('An unknown error occurred whilst copying files')
  end;
end;

//ANATOMY OF AN ITUNES LIBRARY FILE
//iTunes creates a file called "iTunes Music Library.xml" in the directory where
//it stores music. It is intended to be read by other applications to retrieve
//information about the iTunes library.
//It is structured as follows:
// --------------------------------------------
// ¦ -General library information              ¦
// ¦                                           ¦
// ¦ -Sections for each track containing (not  ¦
// ¦   in this order):                         ¦
// ¦  -Track ID                                ¦
// ¦  -Name                                    ¦
// ¦  -Artist                                  ¦
// ¦  -Album                                   ¦
// ¦  -Track number (ie. position in the album)¦
// ¦  -File address                            ¦
// ¦  -And more...                             ¦
// ¦                                           ¦
// ¦ -Sections for each playlist containing a  ¦
// ¦  list of track IDs                        ¦
// ---------------------------------------------

begin
  initialise;
  findPlaylist;
  retrieveTrackIDs;
  gatherTrackIDinfo;
  closeLibraryFile;
  removeUnwanted;
  copyFiles;
  finish;
end.
