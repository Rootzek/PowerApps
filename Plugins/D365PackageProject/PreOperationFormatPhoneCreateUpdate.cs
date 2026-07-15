using System;
using System.Text.RegularExpressions;
using Microsoft.Xrm.Sdk;

namespace D365PackageProject
{
    /// <summary>
    /// Pre-operation plugin for Contact Create/Update to strip non-numeric characters from telephone1.
    /// </summary>
    public class PreOperationFormatPhoneCreateUpdate : PluginBase
    {
        public PreOperationFormatPhoneCreateUpdate(string unsecureConfiguration, string secureConfiguration)
            : base(typeof(PreOperationFormatPhoneCreateUpdate))
        {
            // No configuration required
        }

        protected override void ExecuteDataversePlugin(ILocalPluginContext localPluginContext)
        {
            if (localPluginContext == null)
            {
                throw new ArgumentNullException(nameof(localPluginContext));
            }

            var context = localPluginContext.PluginExecutionContext;

            // Ensure target exists and is an Entity
            if (!context.InputParameters.Contains("Target") || !(context.InputParameters["Target"] is Entity entity))
            {
                return;
            }

            // Only proceed if telephone1 attribute is present and not null
            if (!entity.Attributes.Contains("telephone1") || entity["telephone1"] == null)
            {
                return;
            }

            try
            {
                string phoneNumber = entity["telephone1"].ToString();

                // Remove all non-numeric characters
                string formattedNumber = Regex.Replace(phoneNumber, "[^\\d]", string.Empty);

                entity["telephone1"] = formattedNumber;
            }
            catch (Exception ex)
            {
                // Trace and wrap
                localPluginContext.Trace($"PreOperationFormatPhoneCreateUpdate failed: {ex.Message}");
                throw new InvalidPluginExecutionException("Failed to format telephone1", ex);
            }
        }
    }
}
