using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections;
using Newtonsoft.Json;

namespace Editor
{
    [JsonObject]
    public class ProjectConfigFile
    {
        public string ProjectPath { get; set; }
        public int TileWidth { get; set; }
        public int TileHeight { get; set; }
        public int MapWidth { get; set; }
        public int MapHeight { get; set; }
        public int CurrentLayer { get; set; }
        public int StartMapId { get; set; }
        public int CurrentMapId { get; set; }
        public string TilesetImage { get; set; }
    }

    [JsonObject]
    public class Map
    {
        public string Name { get; set; }
        public int Id { get; set; }
        public List<int> Layer1 { get; set; }
    }
}
