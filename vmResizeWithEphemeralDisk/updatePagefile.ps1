$pagefileVolume = "C"
$pagefile = Get-WmiObject Win32_PagefileSetting
$pagefile.Name = "$pageFileVolume`:\pagefile.sys"
$pagefile.Caption = "$pageFileVolume`:\pagefile.sys"
$pagefile.Description = "'pagefile.sys' @ $pageFileVolume`:\"
$pagefile.SettingID ="pagefile.sys @ $pageFileVolume`:"
$pagefile.put()

$pagefile = Get-WmiObject Win32_PagefileSetting | Where-Object {$_.name -eq "D:\pagefile.sys"}
$pagefile.delete()