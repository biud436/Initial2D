using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

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
                                CurrentLayer = 1,
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
        public int CurrentLayer { get; set; }

        private DataManager()
        {

        }

    }
}
