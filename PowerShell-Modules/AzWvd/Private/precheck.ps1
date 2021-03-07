function precheck {
    <#
    .SYNOPSIS
    PreCheck
    .DESCRIPTION
    This function is used as a precheck step by all the functions to test if authentication is Ok.
    .EXAMPLE
    precheck
    Run the test
    .NOTES
    NAME: precheck
    #>
  
      $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
  
      if ($azProfile.Contexts.Count -ne 0) {
          # Set the subscription from AzContext
          $script:subscriptionId = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext.Subscription.Id
      }
      else {
          Write-Error 'No subscription available, Please use Connect-AzAccount to login and select the right subscription'
          break
      }
  }