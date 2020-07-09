using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Configuration;
using System.Diagnostics;

namespace Editor
{
    public sealed class Config
    {
        private Dictionary<string, string> mData = new Dictionary<string, string>
        {
            { "MapWidth", "17" },
            { "MapHeight", "13" },
            { "MaxLayers", "3" }
        };

        public Config()
        {
            foreach(var i in mData)
            {
                Update(i.Key, i.Value);
            }
        }

        public string Read(string key)
        {
            try
            {
                var appSettings = ConfigurationManager.AppSettings;

                return (appSettings.AllKeys.Contains(key)) ? appSettings[key] : "";
            }
            catch(ConfigurationErrorsException err)
            {
                Debug.Fail(err.Message);
                return "";
            }
        }

        public void Update(string key, int value)
        {
            Update(key, value.ToString());
        }

        public void Update(string key, string value)
        {
            try
            {
                Configuration configuration = ConfigurationManager.OpenExeConfiguration(ConfigurationUserLevel.None);
                var settings = configuration.AppSettings.Settings;

                if (settings[key] == null)
                {
                    settings.Add(key, value);
                }
                else
                {
                    settings[key].Value = value;
                }

                configuration.Save(ConfigurationSaveMode.Modified);
                ConfigurationManager.RefreshSection(configuration.AppSettings.SectionInformation.Name);
            }
            catch(ConfigurationErrorsException err)
            {
                Debug.Fail(err.Message);
            }
        }
    }
}
