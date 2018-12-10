########################################### Create a script execution log file and function ########################################

	$ScriptLogfile = "$ENV:WORKSPACE\UAG-CD\Logs\ScriptLogs\script-execution.log"
	Remove-item -path $ScriptLogfile -ErrorAction SilentlyContinue
	Write-Host "Main script execution logs located at : $ScriptLogfile"
	Write-Output ""

	Function SLog-Write
	{
	   Param ([string]$logstring)
	   
	   Write-Host $logstring
	   Add-content $ScriptLogfile -value $logstring
	}

######################################### Print script start time #############################################

	SLog-Write "------------------------ Script execution started ---------------------------------"
	$Start_time_script = Get-Date
	SLog-Write "Script started at $Start_time_script"
	SLog-Write ""

################################ Load SMTP settings ##########################################################

	.\SMTP-settings.ps1

############################### Download OVA and upgrade UAG nodes on ESXI #####################################

	SLog-Write "Download and upgrade of UAG nodes on ESXI script started"
	SLog-Write " "
	.\Download-Upgrade-EXSI.ps1

############################### Download VHDX for Hyper-V ###################################################

	SLog-Write "Download and upgrade of UAG nodes on Hyper-V script started"
	SLog-Write " "
	.\Download-Upgrade-HyperV.ps1

######################################### Print script start time #############################################

	$Stop_time_script = Get-Date
	SLog-Write "Main script execution completed at $Stop_time_script"
	SLog-Write "-----------------------END of script-----------------------------------------"




