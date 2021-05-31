param hostpoolName string
param hostpoolFriendlyName string
param loadBalancerType string
param preferredAppGroupType string
param location string
param hostPoolType string 

//Create WVD Hostpool
resource hp 'Microsoft.DesktopVirtualization/hostpools@2019-12-10-preview' = {
  name: hostpoolName
  location: location
  properties: {
    friendlyName: hostpoolFriendlyName
    hostPoolType : hostPoolType
    loadBalancerType : loadBalancerType
    preferredAppGroupType: preferredAppGroupType
    
  }
}
