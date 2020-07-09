using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections;
using Newtonsoft.Json;
using System.IO;
using System.Windows.Forms;

namespace Editor
{
    public sealed class ProjectConfigFile
    {
        public string ProjectPath { get; set; }
        public int TileWidth { get; set; }
        public int TileHeight { get; set; }
        public int CurrentLayer { get; set; }
        public int StartMapId { get; set; }
        public int CurrentMapId { get; set; }
        public int WindowWidth { get; set; }
        public int WindowHeight { get; set; }
        public Version Version { get; set; }

        public ProjectConfigFile()
        {
            ProjectPath = Path.GetDirectoryName(Application.StartupPath);
            TileWidth = 16;
            TileHeight = 16;
            CurrentLayer = 1;
            StartMapId = 1;
            CurrentMapId = 1;
            WindowWidth = 640;
            WindowHeight = 480;
            Version = new Version("0.0.1");
        }
    }
}
