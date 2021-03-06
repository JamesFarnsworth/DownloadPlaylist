unit DownloadPlaylistObjects;

{$mode objfpc}{$H+}

interface         //use 'uses' section to relate to other units

type
  tTrack = class(TObject)
  private
    ID, trackNo: integer;
    srcAddress, destAddress, title, album, fileExtension: string;
    procedure determineFileExtension;
  public
    procedure setID(IDinput: integer);
    function getID: integer;
    procedure setSrcAddress(srcInput: string);
    function getSrcAddress: string;
    procedure setDestAddress(destInput: string);
    procedure determineDestAddress(destDirectory: string; destSlash: char);
    function getDestAddress: string;
    procedure setTitle(titleInput: string);
    function getTitle: string;
    procedure setTrackNo(trackNoInput: integer);
    function getTrackNo: integer;
    procedure setAlbum(albumInput: string);
    function getAlbum: string;
  end;

  tSrc = class(TObject)
  private
    iTunesFolder: string;
    slash: char;  //slash is the type of slash used - avoids cross-platform
                  //compatibility issues
    procedure determineSlash;
  public
    procedure setiTunesFolder(iTunesFolderInput: string);
    function getiTunesFolder: string;
    function getSlash: char;
  end;

  tDest = class(TObject)
  private
    folder: string;
    slash: char;
    procedure determineSlash;
  public
    procedure setFolder(folderInput: string);
    function getFolder: string;
    function getSlash: char;
  end;

implementation

uses
  Classes,
  SysUtils,
  StrUtils;

procedure tTrack.determineFileExtension;
var
  stringCount : integer;
begin
  stringCount := length(srcAddress);
  while not (srcAddress[stringCount] = '.') do dec(stringCount);
  fileExtension := rightStr(srcAddress, length(srcAddress) - stringCount + 1);
end;

procedure tTrack.setID(IDinput: integer);
begin
  ID := IDinput;
end;

function tTrack.getID: integer;
begin
  result := ID;
end;

procedure tTrack.setSrcAddress(srcInput: string);
begin
  srcAddress := srcInput;
end;

function tTrack.getSrcAddress: string;
begin
  result := srcAddress;
end;

procedure tTrack.setDestAddress(destInput: string);
begin
  destAddress := destInput;
end;

procedure tTrack.determineDestAddress(destDirectory: string; destSlash: char);
begin
  determineFileExtension;
  destAddress := destDirectory + destSlash + album + destSlash + inttostr(trackNo) + ' ' + title + fileExtension;
end;

function tTrack.getDestAddress: string;
begin
  result := destAddress;
end;

procedure tTrack.setTitle(titleInput: string);
begin
  title := titleInput;
end;

function tTrack.getTitle: string;
begin
  result := title;
end;

procedure tTrack.setTrackNo(trackNoInput: integer);
begin
  trackNo := trackNoInput;
end;

function tTrack.getTrackNo: integer;
begin
  result := trackNo;
end;

procedure tTrack.setAlbum(albumInput: string);
begin
  album := albumInput;
end;

function tTrack.getAlbum: string;
begin
  result := album;
end;

procedure tSrc.setiTunesFolder(iTunesFolderInput: string);
begin
  iTunesFolder := iTunesFolderInput;
  determineSlash;
end;

function tSrc.getiTunesFolder: string;
begin
  result := iTunesFolder;
end;

procedure tSrc.determineSlash;
var
  stringPos: integer;
begin
  if (pos('/', getiTunesFolder) = 0) and (pos('\', getiTunesFolder) = 0) then
    slash := '/' //if there arent any slashes, use a forward slash
  else
  begin
    stringPos := 1;
    while not ((getiTunesFolder[stringPos] = '/') or (getiTunesFolder[stringPos] = '\')) do
      inc(stringPos);
    slash := getiTunesFolder[stringPos];
  end;
end;

function tSrc.getSlash: char;
begin
  result := slash;
end;

procedure tDest.setFolder(folderInput: string);
begin
  folder := folderInput;
  determineSlash;
end;

function tDest.getFolder: string;
begin
  result := folder;
end;

procedure tDest.determineSlash;
var
  stringPos: integer;
begin
  if (pos('/', getFolder) = 0) and (pos('\', getFolder) = 0) then
    slash := '\' //if there arent any slashes, use the windows default
  else
  begin
    stringPos := 1;
    while not ((getFolder[stringPos] = '/') or (getFolder[stringPos] = '\')) do
      inc(stringPos);
    slash := getFolder[stringPos];
  end;
end;

function tDest.getSlash: char;
begin
  result := slash;
end;

end.
