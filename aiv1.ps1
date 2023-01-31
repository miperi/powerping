###### csv configuration ###
# 1. fields= comment,ip,port,email
# 1.1 if the line start with # = ignore this line
# 2. format on ports = 80:tcp
# 3. format for many ports = 80:tcp|53:tcp
# 4. do not sent email (only on total report) if the email = noemail



# Configurable variables
$csvFile = "C:\Users\miper\code\IPs.csv" # Path to the CSV file containing the IPs 
$timeout = 1000 # Maximum milliseeconds time to wait for the port tests
$mailfrom = "testing@testing.gr"
$smtpserveris = "5.5.5.5"
$primaryemailto = "michalis.perivolaris@hd.gr"

#Operations
##reset log file
#New-Item -Path $logFile -ItemType File -Force -ErrorAction SilentlyContinue

#Functions
## write log file of what the script doing
Function Write-Log {
    param(
        [string]$logText,
        [string]$logFileis
    )
    $logText = "$(Get-Date -Format s) `t $logText"
    Add-Content -Path $logFileis -Value $logText 
}
## Sent email
Function Mailing {
    param(
        [string]$tois,
        [string]$subjectis,
        [string]$bodyis
    )
    #$Whenhappen= " $(Get-Date -Format s) "
    if($ip.email -eq "noemail") {
        write-host "ALERT email - but the email is --noemail--"
    }
    else{
    #Send-MailMessage -To $tois -Subject $subjectis+$Whenhappen -Body $bodyis -from $mailfrom -SmtpServer $smtpserveris -ErrorAction SilentlyContinue
    write-host "Email: -To $tois -Subject $subjectis -Body $bodyis -from $mailfrom -SmtpServer $smtpserveris -ErrorAction SilentlyContinue"
    }
}


# Import the CSV file
$ipList = Import-Csv -Path $csvFile
$ipList = $ipList  | Where-Object { $_.comment -notmatch '^#' }

# Create the log folder and log file
$logFolder = "C:\Logs"
$logFile = "$logFolder\IPcheck.log"
$logFileAlert = "$logFolder\IPcheckAlert.log"
New-Item -Path $logFolder -ItemType Directory -Force -ErrorAction SilentlyContinue
New-Item -Path $logFileAlert -ItemType File -Force -ErrorAction SilentlyContinue

# Start logging
Write-Log -logText "INFO`tSystem`tStart testing round" -logFileis $logFile

# Loop through the list of IPs
foreach ($ip in $ipList) {
    # Check the IP address (ping)
    Write-Log -logText "INFO`t$($ip.IP)`t($($ip.comment)) Start testing" -logFileis $logFile
    write-host -ForegroundColor Yellow "INFO`t$($ip.IP)`t($($ip.comment)) Start testing"
    $pingResult = Test-Connection -ComputerName $ip.IP -Count 1  -Quiet -WarningAction SilentlyContinue 
    if ($false -eq $pingResult) {
        # If the ping times out, send the email alert
        $pingalerttxt = "ALERT`t$($ip.IP)`t($($ip.comment)) Address is NOT reachable (ping)"
        Write-Log -logText $pingalerttxt -logFileis $logFile
        Write-Log -logText $pingalerttxt -logFileis $logFileAlert
        write-host -ForegroundColor red $pingalerttxt
        Mailing -tois $ip.email -subjectis $pingalerttxt -bodyis "The IP address $($ip.IP) is not reachable. Please check the connection."        # Log the ping timeout
    }
    else {
        # If the ping does not time out, check the ports
        Write-Log -logText "INFO`t$($ip.IP)`t($($ip.comment)) Address is reachable (ping)" -logFileis $logFile
        Write-host "INFO`t$($ip.IP)`t($($ip.comment)) Address is reachable (ping)"
        $ports = $ip.Port -split '\|'
        foreach ($port in $ports) {
            $portDetails = $port -split ':'
            $tcpClient = [System.Net.Sockets.TcpClient]::new()
            $portresult = $tcpClient.BeginConnect($ip.IP, $portDetails[0], $null, $null)
            $success = $portresult.AsyncWaitHandle.WaitOne($timeout)
            if ($success -eq $True) {
                $tcpClient.EndConnect($portresult)
                $tcpClient.Close()
                Write-host -ForegroundColor Green "INFO`t$($ip.IP)`t($($ip.comment)) Port $($portDetails[0]) is reachable"
                Write-Log -logText "INFO`t$($ip.IP)`t($($ip.comment)) Port $($portDetails[0]) is reachable" -logFileis $logFile
            } else {
                # If the port test fails, send the email alert
                $portalerttxt = "ALERT`t$($ip.IP)`t($($ip.comment)) Port $($portDetails[0]) is NOT reachable"
                $tcpClient.Close()
                Write-Log -logText $portalerttxt -logFileis $logFile
                Write-Log -logText $portalerttxt -logFileis $logFileAlert
                Write-host -ForegroundColor Red $portalerttxt
                Mailing -tois $ip.email -subjectis $portalerttxt  -bodyis "The port $($portDetails[0]) is not reachable on IP address $($ip.IP). Please check the connection." 
            }
        }
    }
}

# End logging
Write-Log -logText "INFO`tSystem`tTest round END" -logFileis $logFile

# Alert with total report if something go wrong
$countAlerts = ""
$countAlerts = (Select-String -Path $logFileAlert -Pattern "ALERT" | Measure-Object).Count
if ($null -ne $countAlerts) {
    write-host -BackgroundColor Yellow "ALERT EVERYONE:"
    $textalert = Get-Content $logFileAlert -Raw
    Mailing -tois $primaryemailto -subjectis "ALERT $($countAlerts) from conn test" -bodyis $textalert
}
Else {
    write-host -BackgroundColor Yellow "NO ALERTS - YEA!"
}

