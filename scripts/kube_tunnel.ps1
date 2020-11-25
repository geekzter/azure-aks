#!/usr/bin/env pwsh

. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) functions.ps1)

Set-Environment

# Open SSH tunnel for local portal on 127.0.0.1:8001
Get-Job | Where-Object {$_.Command.Contains("kubectl proxy")} | Stop-Job
kubectl proxy &

# Wait for agent nodes to have started
Start-Agents
