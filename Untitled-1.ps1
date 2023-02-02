#utp test
if (!(Test-Path -path "C:\LDPorts")) {New-Item "C:\LDPorts" -Type Directory}

#   Set date

$datestring = (Get-Date).ToString("s").Replace(":",".")

function Test-Port{  

[cmdletbinding(  
    DefaultParameterSetName = '',  
    ConfirmImpact = 'low'  
)]  
    Param(  
        [Parameter(  
            Mandatory = $True,  
            Position = 0,  
            ParameterSetName = '',  
            ValueFromPipeline = $True)]  
            [array]$computer,  
        [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [array]$port,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$TCPtimeout=1000,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [int]$UDPtimeout=1000,             
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$TCP,  
        [Parameter(  
            Mandatory = $False,  
            ParameterSetName = '')]  
            [switch]$UDP                                    
        )  
    Begin {  
        If (!$tcp -AND !$udp) {$tcp = $True}  
        #Typically you never do this, but in this case I felt it was for the benefit of the function  
        #as any errors will be noted in the output of the report          
        $ErrorActionPreference = "SilentlyContinue"  
        $report = @()
        $report | Format-List
    }  
    Process {     
        ForEach ($c in $computer) {  
            ForEach ($p in $port) {  
                If ($tcp) {    
                    #Create temporary holder $temp = "" | Select Server, Port, TypePort, Open, Notes   
                    $temp = "" | Select Port, Open
                    #Create object for connecting to port on computer  
                    $tcpobject = new-Object system.Net.Sockets.TcpClient  
                    #Connect to remote machine's port                
                    $connect = $tcpobject.BeginConnect($c,$p,$null,$null)  
                    #Configure a timeout before quitting  
                    $wait = $connect.AsyncWaitHandle.WaitOne($TCPtimeout,$false)  
                    #If timeout  
                    If(!$wait) {  
                        #Close connection  
                        $tcpobject.Close()  
                        Write-Verbose "Connection Timeout"  
                        #Build report  
                        #$temp.Server = $c
                        $temp.Port = $p  
                        #$temp.TypePort = "TCP" 
                        $temp.Open = "Closed or filtered"  
                        #$temp.Notes = "Connection to Port Timed Out"  
                    } Else {  
                        $error.Clear()  
                        $tcpobject.EndConnect($connect) | out-Null  
                        #If error  
                        If($error[0]){  
                            #Begin making error more readable in report  
                            [string]$string = ($error[0].exception).message  
                            $message = (($string.split(":")[1]).replace('"',"")).TrimStart()  
                            $failed = $true  
                        }  
                        #Close connection      
                        $tcpobject.Close()  
                        #If unable to query port to due failure  
                        If($failed){  
                            #Build report   
                            #$temp.Server = $c
                            $temp.Port = $p   
                            #$temp.TypePort = "TCP" 
                            $temp.Open = "Closed or filtered"  
                            #$temp.Notes = "$message"  
                        } Else{  
                            #Build report    
                            #$temp.Server = $c
                            $temp.Port = $p 
                            #$temp.TypePort = "TCP"   
                            $temp.Open = "Open"    
                        }  
                    }     
                    #Reset failed value  
                    $failed = $Null      
                    #Merge temp array with report              
                    $report += $temp  
                }      
                If ($udp) {  
                    #Create temporary holder $temp = "" | Select Server, Port, TypePort, Open, Notes   
                    $temp = "" | Select Port, Open                                    
                    #Create object for connecting to port on computer  
                    $udpobject = new-Object system.Net.Sockets.Udpclient
                    #Set a timeout on receiving message 
                    $udpobject.client.ReceiveTimeout = $UDPTimeout 
                    #Connect to remote machine's port                
                    Write-Verbose "Making UDP connection to remote server" 
                    $udpobject.Connect("$c",$p) 
                    #Sends a message to the host to which you have connected. 
                    Write-Verbose "Sending message to remote host" 
                    $a = new-object system.text.asciiencoding 
                    $byte = $a.GetBytes("$(Get-Date)") 
                    [void]$udpobject.Send($byte,$byte.length) 
                    #IPEndPoint object will allow us to read datagrams sent from any source.  
                    Write-Verbose "Creating remote endpoint" 
                    $remoteendpoint = New-Object system.net.ipendpoint([system.net.ipaddress]::Any,0) 
                    Try { 
                        #Blocks until a message returns on this socket from a remote host. 
                        Write-Verbose "Waiting for message return" 
                        $receivebytes = $udpobject.Receive([ref]$remoteendpoint) 
                        [string]$returndata = $a.GetString($receivebytes)
                        If ($returndata) {
                           Write-Verbose "Connection Successful"  
                            #Build report  
                            #$temp.Server = $c
                            $temp.Port = $p 
                            #$temp.TypePort = "UDP"    
                            $temp.Open = "Open"  
                            #$temp.Notes = $returndata   
                            $udpobject.close()   
                        }                       
                    } Catch { 
                        If ($Error[0].ToString() -match "\bRespond after a period of time\b") { 
                            #Close connection  
                            $udpobject.Close()  
                            #Make sure that the host is online and not a false positive that it is open 
                            If (Test-Connection -comp $c -count 1 -quiet) { 
                                Write-Verbose "Connection Open"  
                                #Build report   
                                #$temp.Server = $c
                                $temp.Port = $p 
                                #$temp.TypePort = "UDP" 
                                $temp.Open = "Open"  
                            } Else { 
                                <# 
                                It is possible that the host is not online or that the host is online,  
                                but ICMP is blocked by a firewall and this port is actually open. 
                                #> 
                                Write-Verbose "Host maybe unavailable"  
                                #Build report   
                                #$temp.Server = $c
                                $temp.Port = $p  
                                #$temp.TypePort = "UDP"  
                                $temp.Open = "Closed or filtered"  
                                #$temp.Notes = "Unable to verify if port is open or if host is unavailable."                                 
                            }                         
                        } ElseIf ($Error[0].ToString() -match "forcibly closed by the remote host" ) { 
                            #Close connection  
                            $udpobject.Close()  
                            Write-Verbose "Connection Timeout"  
                            #Build report  
                            #$temp.Server = $c
                            $temp.Port = $p 
                            #$temp.TypePort = "UDP"
                            $temp.Open = "Closed or filtered"  
                            #$temp.Notes = "Connection to Port Timed Out"                         
                        } Else {                      
                            $udpobject.close() 
                        } 
                    }     
                    #Merge temp array with report              
                    $report += $temp 
                }                                  
            }  
        }                  
    }  
    End {  
        #Generate Report
        $report
    }
}

function TCPtest()
{

Clear-Host
Write-Host -ForegroundColor Yellow "`n`nTesting TCP ports used by LANDESK... (This operation can take up to 30sc)"
$TCPresults = Test-Port -comp $ip -port 80,137,139,443,445,4343,44345,5007,9594,9595,9982,12175,12176,16992,16993,16994,33354 -tcp -TCPtimeout 1800
$TCPresults | Out-File $TCPtxt
Write-Host -ForegroundColor Yellow "`n`nReport has been created in C:\LDPorts\$ip\TCP"
sleep -Seconds 3
explorer.exe "C:\LDPorts\$ip"

}

function UDPtest()
{

Clear-Host
Write-Host -ForegroundColor Yellow "`n`nTesting UDP ports used by LANDESK... (This operation can take up to 15sc)"
$UDPresults = Test-Port -comp $ip -port 53 -udp -UDPtimeout 1800
$UDPresults | Out-File $UDPtxt
Write-Host -ForegroundColor Yellow "`n`nReport has been created in C:\LDPorts\$ip\UDP"
sleep -Seconds 3
explorer.exe "C:\LDPorts\$ip"

}

function Fulltest()
{

Clear-Host
Write-Host -ForegroundColor Yellow "`n`nTesting TCP and UDP ports used by LANDESK... (This operation can take up to 45sc)"
$TCPresults = Test-Port -comp $ip -port 80,137,139,443,445,4343,44345,5007,9594,9595,9982,12175,12176,16992,16993,16994,33354 -tcp -TCPtimeout 1800
$TCPresults | Out-File $TCPtxt
$UDPresults = Test-Port -comp $ip -port 67,69,1759,4011,9535,9595,38293 -udp -UDPtimeout 1800
$UDPresults | Out-File $UDPtxt
Write-Host -ForegroundColor Yellow "`n`nReports have been created in C:\LDPorts\$ip\UDP and C:\LDPorts\$ip\TCP"
sleep -Seconds 4
explorer.exe "C:\LDPorts\$ip"

}

Clear-Host
$ip = Read-Host "`n`nPlease enter the hostname or the IP address of the Core Server, or the CSA/Tunnel"

Clear-Host
Write-Host "`n`nDo you want to check for TCP or UDP ports?"
Write-Host "`n`n`t1. TCP"
Write-Host "`n`t2. UDP"
Write-Host "`n`t3. TCP and UDP"
$Protocol = Read-Host "`n`nPlease enter your choice number"

Clear-Host

if (!(Test-Path -path "C:\LDPorts\$ip")) {New-Item "C:\LDPorts\$ip" -Type Directory}
if (!(Test-Path -path "C:\LDPorts\$ip\UDP")) {New-Item "C:\LDPorts\$ip\UDP" -Type Directory}
if (!(Test-Path -path "C:\LDPorts\$ip\TCP")) {New-Item "C:\LDPorts\$ip\TCP" -Type Directory}

$TCPtxt = "C:\LDPorts\$ip\TCP\TCPportsCheck-$ip-$datestring.txt"
$UDPtxt = "C:\LDPorts\$ip\UDP\UDPportsCheck-$ip-$datestring.txt"

switch ($Protocol)
        {
        1{TCPtest}
        2{UDPtest}
        3{Fulltest}
        }


