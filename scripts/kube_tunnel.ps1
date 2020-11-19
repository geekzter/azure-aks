#!/usr/bin/env pwsh

param(
    [parameter(Mandatory=$false)][string]$workspace
)

# Start agent nodes (if not already started)
& (Join-Path (Split-Path -parent -Path $MyInvocation.MyCommand.Path) "start_agents.ps1") -workspace $workspace -nowait

# Update ~/.kube/config
& (Join-Path (Split-Path -parent -Path $MyInvocation.MyCommand.Path) "kube_config.ps1") -workspace $workspace

# Open SSH tunnel for local portal on 127.0.0.1:8001
Get-Job | Where-Object {$_.Command.Contains("kubectl proxy")} | Stop-Job
kubectl proxy &

# Wait for agent nodes to have started
& (Join-Path (Split-Path -parent -Path $MyInvocation.MyCommand.Path) "start_agents.ps1") -workspace $workspace