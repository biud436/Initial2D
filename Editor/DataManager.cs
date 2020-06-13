using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Collections;

namespace Editor
{
    public class DataManager
    {
        private static volatile DataManager instance;
        private static object syncRoot = new Object();

        public static DataManager Instance
        {
            get
            {
                if (instance == null)
                {
                    lock (syncRoot)
                    {
                        if (instance == null)
                        {
                            instance = new DataManager
                            {
                                ProjectPath = System.IO.Path.GetDirectoryName(Application.StartupPath),
                                TileWidth = 16,
                                TileHeight = 16,
                                MapWidth = 17,
                                MapHeight = 13,
                                CurrentLayer = 1,
                                Tilemap = new int[256],
                                TilesetImage = "",
                            };
                        }
                    }
                }

                return instance;
            }
        }

        public string ProjectPath { get; set; }
        public int TileWidth { get; set; }
        public int TileHeight { get; set; }
        public int MapWidth { get; set; }
        public int MapHeight { get; set; }
        public int CurrentLayer { get; set; }
        public int[] Tilemap { get; set; }
        public string TilesetImage { get; set; }

        private DataManager()
        {

        }

    }
}
