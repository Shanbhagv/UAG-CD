###########################################  Query Buildweb for Latest Build  ########################################### 

	Write-Host "Start of Query Build Web for Latest UAG build"
	$url_query_product_branch = 'http://buildapi.eng.vmware.com/ob/build/?product=euc-access-point&branch=master&buildstate=succeeded&buildtype=beta&id__gt=10923663&_order_by=-endtime&_limit=1&_format=json'
	#Write-Host "Method : GET, Url : $url_query_product_branch"
	#Write-Host ""
	$response_url_query_product_branch=Invoke-RestMethod  -Method Get -Uri $url_query_product_branch
	#Write-Host "Response : $response_url_query_product_branch"
	#Write-Host ""
	$deliverables_url=""
	$build_number=""
	$deliverables_url=$response_url_query_product_branch._list._deliverables_url
	#Write-Host "deliverables_url : $deliverables_url" # example http://buildapi.eng.vmware.com/ob/deliverable/?build=5745527&_format=json
	#Write-Host ""   
	$build_number="UNKNOWN_BUILD_#"
	If( $deliverables_url -match "(\d+)") 
	{
			$build_number=$matches[1] # example 5745527
	}
	Write-Host "build_number: $build_number"  
	Write-Host ""  

########################################### Create a build log file #################################################################

	$BuildLogfile = "$ENV:WORKSPACE\UAG-CD\Logs\BuildLogs\ESXI\$build_number.log"
	Remove-item -path $BuildLogfile -ErrorAction SilentlyContinue
	Write-Host "Build dowload log file is located at : $BuildLogfile"
	Function Log-Write
	{
	   Param ([string]$logstring)
	   
	   Write-Host $logstring
	   Add-content $BuildLogfile -value $logstring
	}

######################################### Print BuildLog start time #############################################

	Log-Write "------------------------ Build download and upgrade script execution started ---------------------------------"
	$Start_time_script = Get-Date
	Log-Write "Build Script started at $Start_time_script" ; Log-Write ""
	
###########################################  Query Build web and get url to download UGA ova  #########################################
	
	Log-Write "***************Query latest build available on Buildweb and get url to download*************"; Log-Write ""
# Using the latest build number get the downloadable artifacts of the build like .ova, .ovf, etc
	$url_build_deliverables = "http://buildapi.eng.vmware.com$deliverables_url&_format=json"
	#Write-Host  "Method : GET, Url : $url_build_deliverables"
	#Write-Host ""  
	#From the response parse through each 
	$response_url_build_deliverables=Invoke-RestMethod  -Method Get -Uri $url_build_deliverables
	#Write-Host "Response_url_build_deliverables : $response_url_build_deliverables"
	#Write-Host ""
	$url_build_download=""
	$md5FromBuildWeb=""
	foreach( $node in $response_url_build_deliverables._list) 
	{
		If( $node -match "_download_url=(.*?.ova)")
		{
			$url_build_download=$matches[1]
			# http://buildweb.eng.vmware.com/ob/api/5745527/deliverable/?file=publish/euc-unified-access-gateway-3.1.0.0-5745527_OVF10.ova
					If( $node -match "md5=(.*?);") 
					{
					  $md5FromBuildWeb=$matches[1]
					  $md5FromBuildWeb=$md5FromBuildWeb.ToUpper()
					}
		}
	}

	If ($url_build_download -ne "") 
	{
		Log-Write "Found Build Download Url : $url_build_download";
		Log-Write "Found md5 from buildWeb  : $md5FromBuildWeb";
	}
	Else 
	{
		Log-Write "Error in finding build Download Url : $url_build_download";
		exit
	}

	If( $url_build_download -match "(euc-unified-access-gateway-(?!fips).*?.ova)") 
	{
			
		$ovaFilename=$matches[1] # euc-unified-access-gateway-3.1.0.0-5745527_OVF10.ova
		Log-Write "ovaFilename              : $ovaFilename"
		Log-Write "Non FIPS build found!"; Log-Write ""
	}
	Elseif ( $url_build_download -match "(euc-unified-access-gateway-fips.*?.ova)")
	{
		Log-Write "It's a FIPS build!"
		$ovaFilename=$matches[1]
		Log-Write "ovaFilename              : $ovaFilename"; 
		Log-Write "EXIT"
		$emailMessage.Subject = "NOTIFICATION : ESXI UAG lab auto upgrade status - Skip build download and upgarde" 
		$emailMessage.Body = "Skipping auto upgrade since top build is FIPS build - $ovaFilename"
		#$SMTPClient.Send( $emailMessage )
		exit
	}

###########################################    Download UAG ova from Build Web using download url    ########################################### 

	$ova_file_path="H:\UAG-CD\Installers\$ovaFilename"
	$LatestBuild_path="H:\UAG-CD\Installers\LastInstallerDeployed-ova\$ovaFilename"
	Log-Write "*******Check whether latest build available on buildWeb is already consumed*****"
	if (Test-Path $LatestBuild_path) 
	{
		Log-Write "Latest build available on buildWeb is already consumed, Build present at - $LatestBuild_path"
		Log-Write "EXIT"
#Send email about build download and upgrade skip
		$emailMessage.Subject = "NOTIFICATION : ESXI UAG lab auto upgrade status - Skip build download and upgarde" 
		$emailMessage.Body = "Skipping auto upgrade since new build is NOT available, nodes are already running with latest build - $ovaFilename"
		#$SMTPClient.Send( $emailMessage )
		exit
	} 
	else 
	{	Log-Write "**************New build is available, download starts*************"
		Log-Write " "
#Send email about new build availabilty.
	$emailMessage.Subject = "NOTIFICATION : ESXI UAG lab auto upgrade status - New build found" 
	$emailMessage.Body = "We have new UAG build available- $ovaFilename, Let's get it!"
	#$SMTPClient.Send( $emailMessage )
    $time_before_download=Get-Date
    Log-Write "Download UAG ova from Build Web using download url Start "
    Log-Write "Saving ova file to path      : $ova_file_path"
    Log-Write "Trying to download the ova   : $url_build_download "; Log-Write ""
    $start_time_download = Get-Date
    $webClient = New-Object –TypeName System.Net.WebClient
    $webClient.DownloadFile("$url_build_download", $ova_file_path)
    $time_after_download=Get-Date
 
    $time_taken_to_download=$time_after_download-$time_before_download
    Log-Write "Time taken to download build : $($time_taken_to_download.TotalMinutes) minutes"; Log-Write " "
    #Log-Write "Time taken to download build : $($time_taken_to_download.TotalSeconds) seconds"
    
    Log-Write "******Check if the downloded file exits******"
    if (Test-Path $ova_file_path) {
        Log-Write "Pass - Downloaded file EXISTS             : $ova_file_path"
		Remove-Item –path H:\UAG-CD\Installers\LastInstallerDeployed-ova\* -include *.ova
		Copy-Item -Path $ova_file_path -Destination H:\UAG-CD\Installers\LastInstallerDeployed-ova
		Log-Write "Copied file to H:\UAG-CD\Installers\LastInstallerDeployed-ova to check latest build consumption in next run"; Log-Write ""
    } 
	else
	{
        Log-Write "Fail - Downlodeded File DOES NOT EXISTS    : $ova_file_path"
        Log-Write "EXIT"
        exit
    }
    
	Log-Write "*****Rename downloded build to static name 'euc-unified-access-gateway.ova' just to make deployment logic simple!****"
	Remove-Item –path H:\UAG-CD\Installers\euc-unified-access-gateway.ova –recurse
	Rename-Item "$ova_file_path" "euc-unified-access-gateway.ova" 
	$ova_static_file_path="H:\UAG-CD\Installers\euc-unified-access-gateway.ova"
	Log-Write "Renamed"
	
	Log-Write "*****Validate build downloded completely by Checking if the md5 of the ova file is correct***********"
	$cmd_compute_md5="Get-FileHash $ova_static_file_path -Algorithm MD5 | Select-Object -ExpandProperty Hash"
	$md5FromFile= iex $cmd_compute_md5
	Log-Write  "md5 from buildWeb           : $md5FromBuildWeb"
	Log-Write  "md5 from file               : $md5FromFile" ; Log-Write ""
	If( $md5FromFile -eq $md5FromBuildWeb)
	{
		Log-Write  "Varified: Successfull download of latest UAG Beta Build"
	}
	Else 
	{
		Log-Write  "Fail                        : The md5 value from buildweb is NOT MATCHING with md5sum from ova file."
		Log-Write  "EXIT"
		exit
	}

######################################### Print Build-Download complete time #############################################

	$Stop_time_script = Get-Date
	Log-Write "Build download Script completed at $Stop_time_script"
	Log-Write ""

######################################### Print Build-Deployment start time #############################################

	$Start_time_script = Get-Date
	Log-Write "Build deployment Script started at $Stop_time_script"; Log-Write ""

######################################### UAG Auto Deployment on ESXI Begins #####################################################

	Log-Write "UAG Auto Deployment on ESXI script called"; Log-Write " "
	.\Esxi-nodes.ps1
	Log-Write "Deployment of UAG on ESXI Complted"; Log-Write " "
	
######################################### Print Build-Deployment complete time #############################################

	$Stop_time_script = Get-Date
	Log-Write "Build deployment Script completed at $Stop_time_script"; Log-Write ""

##################################### Print time took to deploy latest build on all nodes ################################

	$time_taken_to_deploy=$Stop_time_script-$Start_time_script
    Log-Write "Time taken to deploy build on all nodes: $($time_taken_to_deploy.TotalMinutes) minutes"
	
##################################### Send email on completion on upgrade ##############################################
	
#Send upgrade complete email
	$emailMessage.Subject = "NOTIFICATION : ESXI UAG lab auto upgrade status - Upgrade Complete" 
	$emailMessage.Body = "Upgrade of all UAG nodes are completed with latest build - $ovaFilename.
	
	Nodes Details:
	TLS Port share lab:
	TLSFE1 - 172.16.64.137
	TLSFE2 - 172.16.64.175
	TLSBE1 - 172.16.64.139
	
	HA LB lab:
	HAFE1 - 172.16.64.206
	HAFE2 - 172.16.64.241
	HAFE3 - 172.16.64.251
	HABE1 - 172.16.64.252
	HABE2 - 172.16.64.255
	
	Non standard port lab:
	non-stan - 172.16.66.73
	non-stanb - 172.16.66.74
	
	PT lab:
	HAPTFE1 - 172.16.65.16
	HAPTFE2 - 172.16.65.19
	HAPTBE1 - 172.16.65.22
	HAPTBE2 - 172.16.65.23
	
	Individual servers:
	tns_uag - DHCP
	ts_uag - DHCP
	
	Best Regards"
	$SMTPClient.Send( $emailMessage )
	SLog-Write "------------------------ Build download and upgrade script execution completed ---------------------------------"
}