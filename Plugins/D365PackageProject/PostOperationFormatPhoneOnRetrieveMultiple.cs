using D365PackageProject;
using Microsoft.Xrm.Sdk;
using System;

namespace PostOperationFormatPhoneOnRetrieveMultiple
{
    /// <summary>
    /// Plugin development guide: https://docs.microsoft.com/powerapps/developer/common-data-service/plug-ins
    /// Best practices and guidance: https://docs.microsoft.com/powerapps/developer/common-data-service/best-practices/business-logic/
    /// </summary>
    public class PostOperationFormatPhoneOnRetrieveMultiple : PluginBase
    {
        public PostOperationFormatPhoneOnRetrieveMultiple(string unsecureConfiguration, string secureConfiguration)
            : base(typeof(PostOperationFormatPhoneOnRetrieveMultiple))
        {
            // TODO: Implement your custom configuration handling
            // https://docs.microsoft.com/powerapps/developer/common-data-service/register-plug-in#set-configuration-data
        }

        // Entry point for custom business logic execution
        protected override void ExecuteDataversePlugin(ILocalPluginContext localPluginContext)
        {
            if (localPluginContext == null)
            {
                throw new ArgumentNullException(nameof(localPluginContext));
            }

            var context = localPluginContext.PluginExecutionContext;

            if (context.MessageName.Equals("Retrieve"))
            {
                if (!context.OutputParameters.Contains("BusinessEntity") && context.OutputParameters["BusinessEntity"] is Entity)
                    throw new InvalidPluginExecutionException("No business entity found");

                var entity = (Entity)context.OutputParameters["BusinessEntity"];

                if (!entity.Attributes.Contains("telephone1"))
                    return;

                if (!long.TryParse(entity["telephone1"].ToString(), out long phoneNumber))
                    return;

                var formattedNumber = String.Format("{0:(###) ###-####}", phoneNumber);
                entity["telephone1"] = formattedNumber;
            }
            else if (context.MessageName.Equals("RetrieveMultiple"))
            {
                if (!context.OutputParameters.Contains("BusinessEntityCollection") && context.OutputParameters["BusinessEntityCollection"] is EntityCollection)
                    throw new InvalidPluginExecutionException("No business entity collection found");

                var entityCollection = (EntityCollection)context.OutputParameters["BusinessEntityCollection"];

                foreach (var entity in entityCollection.Entities)
                {
                    if (entity.Attributes.Contains("telephone1") && entity["telephone1"] != null)
                    {
                        if (long.TryParse(entity["telephone1"].ToString(), out long phoneNumber))
                        {
                            var formattedNumber = String.Format("{0:(###) ###-####}", phoneNumber);
                            entity["telephone1"] = formattedNumber;
                        }
                    }
                }
            }
        }
    }
}
