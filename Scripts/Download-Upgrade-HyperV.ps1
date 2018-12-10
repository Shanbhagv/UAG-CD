######################## UnZIP Function #################################################
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	function unzip 
		{
		param( [string]$ziparchive, [string]$extractpath )
		[System.IO.Compression.ZipFile]::ExtractToDirectory( $ziparchive, $extractpath )
		}

########################################### Query Buildweb for Latest Build ########################################### 

	Write-Host "Start of Query Build Web for Latest UAG build"

#Query Build web for latest Build
	$url_query_product_branch = 'http://buildapi.eng.vmware.com/ob/build/?product=euc-access-point-microsoft&branch=master&buildstate=succeeded&buildtype=release&id__gt=7975514&_order_by=-endtime&_limit=1&_format=json'

	#Write-Host "Method : GET, Url : $url_query_product_branch"

	$response_url_query_product_branch=Invoke-RestMethod  -Method Get -Uri $url_query_product_branch
	$deliverables_url=""
	$build_number=""
	$deliverables_url=$response_url_query_product_branch._list._deliverables_url

	#Write-Host "`ndeliverables_url : $deliverables_url"    # example http://buildapi.eng.vmware.com/ob/deliverable/?build=5745527&_format=json

	$build_number="UNKNOWN_BUILD_#"
	If( $deliverables_url -match "(\d+)") 
		{
			$build_number=$matches[1] # example 5745527
		}

	Write-Host "build_number: $build_number"   

########################################### Create a build log file #################################################################

	$BuildLogfile = "$ENV:WORKSPACE\UAG-CD\Logs\BuildLogs\Hyper-V\$build_number.log"
	Remove-item -path $BuildLogfile -ErrorAction SilentlyContinue
	Write-Host "Build download logs are located at : $BuildLogfile"
	Function Log-Write
	{
	   Param ([string]$logstring)
	   
	   Write-Host $logstring
	   Add-content $BuildLogfile -value $logstring
	}

###########################################  Query Build web and get url to download UGA Build  #########################################

	Log-Write "Query Build web and get url to download UGA ova Start"
#Using the latest build number get the downloadable artifacts of the build like .ova, .ovf, .vhdx etc
	$url_build_deliverables = "http://buildapi.eng.vmware.com$deliverables_url&_format=json"
	#Write-Host  "Method : GET, Url : $url_build_deliverables"
	#From the response parse through each 
	$response_url_build_deliverables=Invoke-RestMethod  -Method Get -Uri $url_build_deliverables
	#Write-Host "$response_url_build_deliverables : `n $response_url_build_deliverables"
	$url_build_download=""
	$md5FromBuildWeb=""
	foreach( $node in $response_url_build_deliverables._list)
	{
		If( $node -match "_download_url=(.*?vhdx.zip)")
		{
			$url_build_download=$matches[1]
			# http://buildweb.eng.vmware.com/ob/api/5745527/deliverable/?file=publish/euc-unified-access-gateway-3.1.0.0-5745527_OVF10-vhdx.zip
					If( $node -match "md5=(.*?);") 
					{
					  $md5FromBuildWeb=$matches[1]
					  $md5FromBuildWeb=$md5FromBuildWeb.ToUpper()
					}
		}
	}

	If ($url_build_download -ne "") 
	{
		Log-Write ""
		Log-Write "Found Build Download Url : $url_build_download";
		Log-Write "Found md5 from buildWeb  : $md5FromBuildWeb";
	}
	Else 
	{
		Log-Write "Error in finding build Download Url : $url_build_download";
			exit
	}


	#If( $url_build_download -match "(euc.*?.ova)") {
	If( $url_build_download -match "(euc-unified-access-gateway-(?!fips).*?vhdx.zip)") 
	{
			#Write-Host "Matched Node : $node"
			$ovaFilename=$matches[1] # euc-unified-access-gateway-3.1.0.0-5745527_OVF10-vhdx.zip
	}

	Log-Write "ovaFilename              : $ovaFilename"
	Log-Write "Query Build web and get url to download UGA ova End ";Log-Write " "

###########################################    Download UAG ova from Build Web using download url    ########################################### 
	$ova_file_path="H:\UAG-CD\Installers\$ovaFilename"
	$LatestBuild_path="H:\UAG-CD\Installers\LastInstallerDeployed-vhdx\$ovaFilename"

	Log-Write "******Check latest build is already consumed******" ; Log-Write " "
	if (Test-Path $LatestBuild_path) 
	{
		Log-Write "Skipping downloading ova file as the following file aleady exists : $LatestBuild_path"; Log-Write " "
		$emailMessage.Subject = "NOTIFICATION : Hyper-V UAG lab auto upgrade status - Skip build download and upgarde" 
		$emailMessage.Body = "Skipping auto upgrade since new build is NOT available, nodes are already running with latest build - $ovaFilename "
		#$SMTPClient.Send( $emailMessage )
		exit
} 
	else 
	{	
		Log-Write "New UAG build -$ovaFilename is available, download begins"; Log-Write " "
	
#Send email about new build availabilty.
		$emailMessage.Subject = "NOTIFICATION : Hyper-V UAG lab auto upgrade status - New build found" 
		$emailMessage.Body = "New UAG build is available- $ovaFilename, Download started!"
		#$SMTPClient.Send( $emailMessage )
		$time_before_download=Get-Date
		Log-Write "Saving ova file to path      : $ova_file_path" ; Log-Write " " 
		Log-Write "Trying to download the ova   : $url_build_download" ; ; Log-Write " " 
		$start_time_download = Get-Date
		$webClient = New-Object –TypeName System.Net.WebClient
		$webClient.DownloadFile("$url_build_download", $ova_file_path)
		$time_after_download=Get-Date
		$time_taken_to_download=$time_after_download-$time_before_download
		Log-Write "Time taken to download build : $($time_taken_to_download.TotalMinutes) minutes"
		#Log-Write "Time taken to download build : $($time_taken_to_download.TotalSeconds) seconds"
		Log-Write "Download Complete"; Log-Write " "

		Log-Write "****Check if the ova file exits****" ; Log-Write ""
    if (Test-Path $ova_file_path)
	{
        Log-Write "Pass - File EXISTS at $ova_file_path"
		Log-Write "Latest UAG build download is complete"
		Remove-Item –path H:\UAG-CD\Installers\* -include *.vhdx
		Remove-Item –path H:\UAG-CD\Installers\LastInstallerDeployed-vhdx\* -include *.zip
		Copy-Item -Path $ova_file_path -Destination H:\UAG-CD\Installers\LastInstallerDeployed-vhdx
    } 
	else 
	{
        Log-Write "Fail - File DOES NOT EXISTS at $ova_file_path , Hence exiting the program."
        exit
    }
	  
	Log-Write "******Validate downloded build by comparing md5 hash value************";Log-Write " "
	$cmd_compute_md5="Get-FileHash $ova_file_path -Algorithm MD5 | Select-Object -ExpandProperty Hash"
	$md5FromFile= iex $cmd_compute_md5
	Log-Write  "md5 from buildWeb           : $md5FromBuildWeb"
	Log-Write  "md5 from file               : $md5FromFile"
	If( $md5FromFile -eq $md5FromBuildWeb) 
	{
		Log-Write  "Downloded build is verified successfully."
	}
	Else 
	{
		Log-Write  "The md5 value from buildweb is NOT MATCHING with md5sum from downloded ova file, exit.."
		exit
	}

######################################## Preparation for Auto deployment ##############################################

#Unzip folder, delete zip folder, rename vhdx file
	unzip "$ova_file_path" "H:\UAG-CD\Installers"
	Log-Write " "
	Log-Write "Extract succesfful"
	Remove-Item –path H:\UAG-CD\Installers\*.zip –recurse
	Log-Write "Remove zip folder is succesfull"
	Get-ChildItem H:\UAG-CD\Installers\*.vhdx | Rename-Item -NewName 'euc-unified-access-gateway.vhdx' 
	Log-Write "Renamed latest build to static name euc-unified-access-gateway.vhdx"; Log-Write ""
	
######################################### Print BuildLog complete time #############################################
	
	$Stop_time_script = Get-Date
	Log-Write "Build download Script completed at $Stop_time_script"; Log-Write ""
	
######################################### Print Build-Deployment start time #############################################

	$Start_time_script = Get-Date
	Log-Write "Build download Script completed at $Stop_time_script"; Log-Write ""
	
######################################### UAG Auto Deployment on Hyper-V Begins #####################################################

	Log-Write "UAG Auto Deployment on Hyper-V  will begin now"; Log-Write " "
	.\HyperV-nodes.ps1
	Log-Write "Deployment of UAG on Hyper-V Complted"; Log-Write " "

######################################### Print Build-Deployment complete time #############################################

	$Stop_time_script = Get-Date
	Log-Write "Build download Script completed at $Stop_time_script"; Log-Write ""
	
##################################### Print time took to deploy latest build on all nodes ################################

	$time_taken_to_deploy=$Stop_time_script-$Start_time_script
    Log-Write "Time taken to download build : $($time_taken_to_deploy.TotalMinutes) minutes"
		
#Send upgrade complete email
	$emailMessage.Subject = "NOTIFICATION : Hyper-V UAG lab auto upgrade status - Upgrade Complete" 
	$emailMessage.Body = "Upgrade of all Hyper-v UAG nodes are completed with latest build - $ovaFilename.
	
	Nodes Details:
	UAGHPV1 - 172.16.90.112
	UAGHPV2 - 172.16.90.113
	UAGHPV3 - 172.16.90.114
	UAGHPV4 - 172.16.90.115
	
	Best Regards"
	$SMTPClient.Send( $emailMessage )
	SLog-Write "------------------------ Script execution Complted ---------------------------------"
}