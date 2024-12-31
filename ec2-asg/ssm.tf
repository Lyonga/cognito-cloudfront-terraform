# Terraform Configuration for Agent Installation using SSM and EventBridge
# Retrieve Falcon Client ID from Parameter Store
data "aws_region" "current" {}
data "aws_ssm_parameter" "falcon_client_id" {
  name            = var.falcon_client_id_parameter_name
  with_decryption = true
}

# Retrieve Falcon Client Secret from Parameter Store
data "aws_ssm_parameter" "falcon_client_secret" {
  name            = var.falcon_client_secret_parameter_name
  with_decryption = true
}


resource "aws_iam_role" "automation_role" {
  name               = var.automation_role_name
  assume_role_policy = data.aws_iam_policy_document.assume_ssm_role.json
}

resource "aws_iam_role_policy" "automation_policy" {
  role   = aws_iam_role.automation_role.id
  policy = data.aws_iam_policy_document.ssm_policy.json
}

data "aws_iam_policy_document" "assume_ssm_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm_policy" {
  statement {
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:GetCommandInvocation",
      "ssm:DescribeInstanceInformation",
      "ssm:ListAssociations",
      "ssm:UpdateAssociation"
    ]
    resources = ["*"]
  }
}

resource "aws_ssm_document" "install_agents" {
  name          = "NglSecurityAgentInstallationDocument"
  document_type = "Automation"
  tags =          var.tags
  content = jsonencode({
    schemaVersion = "0.3"
    #schemaVersion = "2.2"
    description   = "Install security agents on EC2 instances."
    parameters    = {
      InstanceIds  = { type = "StringList", description = "List of EC2 Instance IDs." }
      S3BucketName = { type = "String", description = "S3 bucket containing the installers.", default = "${var.bucket_name}"}
      Region       = { type = "String", default = "${data.aws_region.current.name}" }
    }
    mainSteps = [
      # {
      #   "name": "DownloadAWSCLI",
      #   "action": "aws:downloadContent",
      #   "inputs": {
      #     "sourceType": "HTTP",
      #     "sourceInfo": "{\"path\":\"https://awscli.amazonaws.com/AWSCLIV2.msi\"}",
      #     "destinationPath": "C:\\Temp\\AWSCLIV2.msi"
      #   }
      # }
      {
        "name": "DownloadAWSCLI",
        "action": "aws:runCommand",
        "inputs": {
          "DocumentName": "AWS-RunPowerShellScript",
          "InstanceIds": "{{ InstanceIds }}",
          "Parameters": {
            "commands": [
              "$path = 'C:\\Temp\\AWSCLIV2.msi'",
              "$url  = 'https://awscli.amazonaws.com/AWSCLIV2.msi'",
              "New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null",
              "Invoke-WebRequest -Uri $url -OutFile $path"
            ]
          }
        }
      },
      {
        "name": "InstallAWSCLI",
        "action": "aws:runCommand",
        "inputs": {
          "DocumentName": "AWS-RunPowerShellScript",
          "InstanceIds": "{{ InstanceIds }}",
          "Parameters": {
            "commands": [
              "Start-Process msiexec -ArgumentList \"/i C:\\Temp\\AWSCLIV2.msi /quiet /norestart\" -Wait"
            ]
          }
        }
      },
      {
        name     = "InstallCrowdStrike"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$installer = \"C:\\Scripts\\CROWDSTRIKE.EXE\"",
              "aws s3 cp s3://${var.bucket_name}/CROWDSTRIKE.EXE $installer",
              "Start-Process $installer -Wait"
            ]
          }
        }
      },
      {
        name     = "InstallRapid7"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$installer = \"C:\\Scripts\\RAPID7_X86_64.MSI\"",
              "aws s3 cp s3://${var.bucket_name}/RAPID7_X86_64.MSI $installer",
              "Start-Process $installer -Wait"
            ]
          }
        }
      },
      {
        name     = "InstallDuo"
        action   = "aws:runCommand"
        inputs   = {
          DocumentName = "AWS-RunPowerShellScript"
          InstanceIds  = "{{ InstanceIds }}"
          Parameters   = {
            commands = [
              "$installer = \"C:\\Scripts\\DUOWINDOWSLO6OG4.MSI\"",
              "aws s3 cp s3://${var.bucket_name}/DUOWINDOWSLO6OG4.MSI $installer",
              "Start-Process msiexec -ArgumentList \"/i $installer /quiet /norestart\" -Wait"
            ]
          }
        }
      }
    ]
  })
}


resource "aws_ssm_association" "install_crowdstrike" {
  name = aws_ssm_document.crowdstrike_install.name
  #name = aws_ssm_document.install_agents.name
  document_version = "$DEFAULT"
  parameters = {
    FalconClientID    = data.aws_ssm_parameter.falcon_client_id.value
    #FalconClientSecret = data.aws_ssm_parameter.falcon_client_secret.value
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.generic.id]
  }
#   targets {
#     key    = "tag:${var.tag_key}"
#     values = [var.tag_value]
#   }
  #targets              = [{ Key = "tag:${var.target_tag_key}", Values = [var.target_tag_value] }]
  max_concurrency      = var.max_concurrency
  max_errors           = var.max_errors
  compliance_severity  = "CRITICAL"
  depends_on = [aws_instance.generic]
}




# 3) Define a custom SSM Document to download & install the CrowdStrike sensor
resource "aws_ssm_document" "crowdstrike_install" {
  name          = "Install-CrowdStrike-Sensor"
  document_type = "Command"
  content = <<-DOC
  {
    "schemaVersion": "2.2",
    "description": "Install the CrowdStrike Windows sensor from GitHub script",
    "parameters": {
      "FalconClientID": {
        "type": "String",
        "description": "Falcon Client ID"
      }
    },
    "mainSteps": [
      {
        "action": "aws:runPowerShellScript",
        "name": "InstallCrowdstrikeSensor",
        "inputs": {
          "runCommand": [
            "$client = New-Object System.Net.WebClient",
            "$client.DownloadFile('https://raw.githubusercontent.com/CrowdStrike/Cloud-AWS/master/Agent-Install-Examples/powershell/sensor_install.ps1', 'C:\\\\Windows\\\\Temp\\\\sensor.ps1')",
            "powershell.exe C:\\\\Windows\\\\Temp\\\\sensor.ps1 {{FalconClientID}} {{FalconClientSecret}}",
            "Remove-Item 'C:\\\\Windows\\\\Temp\\\\sensor.ps1' -Force"
          ]
        }
      }
    ]
  }
  DOC
}


# resource "aws_ssm_document" "install_agents_windows" {
#   name            = "InstallCrowdstrikeDuoRapid7Test"
#   document_type   = "Command"
#   document_format = "YAML"

#   content = <<-DOC
#     schemaVersion: "2.2"
#     description: "Installs CrowdStrike, Duo, and Rapid7 on Windows via PowerShell."
#     parameters: {}
#     mainSteps:
#       - action: aws:runPowerShellScript
#         name: InstallAgents
#         inputs:
#           runCommand:
#             - "Write-Host 'Downloading and Installing CrowdStrike, Duo, and Rapid7...'"
#             - "New-Item -ItemType Directory -Force -Path 'C:\\Temp' | Out-Null"

#             - "powershell -Command \"(New-Object Net.WebClient).DownloadFile('${var.crowdstrike_exe_s3_url}', 'C:\\Temp\\CrowdStrikeSetup.exe')\""
#             - "Start-Process 'C:\\Temp\\CrowdStrikeSetup.exe' -ArgumentList '/quiet' -Wait"

#             - "powershell -Command \"(New-Object Net.WebClient).DownloadFile('${var.duo_msi_s3_url}', 'C:\\Temp\\DuoSetup.msi')\""
#             - "Start-Process 'msiexec.exe' -ArgumentList '/i C:\\Temp\\DuoSetup.msi /quiet /qn' -Wait"

#             - "powershell -Command \"(New-Object Net.WebClient).DownloadFile('${var.rapid7_msi_s3_url}', 'C:\\Temp\\Rapid7Setup.msi')\""
#             - "Start-Process 'msiexec.exe' -ArgumentList '/i C:\\Temp\\Rapid7Setup.msi /quiet /qn' -Wait"

#             - "Write-Host 'All agents installed successfully.'"
#   DOC
# }


