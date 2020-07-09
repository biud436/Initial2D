using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using System.Diagnostics;
using System.Runtime;
using Editor.Core;

namespace Editor
{
    public sealed class Map : ICloneable
    {
        public static int WIDTH = 17;
        public static int HEIGHT = 13;

        public string Name { get; set; }
        public int Id { get; set; }
        public Layer Layer { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        public string TilesetImage { get; set; }

        public Map()
        {
            this.Width = WIDTH;
            this.Height = HEIGHT;
        }

        public Map(int width, int height, int mapId)
        {
            this.Width = width;
            this.Height = height;
            this.Id = mapId;
        }

        public void SetMapName(string mapName)
        {
            Name = mapName;
        }

        public void SetTilesetImage(string tilesetImage)
        {
            TilesetImage = tilesetImage;
        }

        public object Clone()
        {
            return this.MemberwiseClone();
        }
    }
}
