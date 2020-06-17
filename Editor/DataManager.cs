using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Collections;
using System.IO;
using Newtonsoft.Json;

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
                            instance = new DataManager();
                            instance.Import();
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
        public List<int> Layer1 { get; set; }
        public string TilesetImage { get; set; }

        private DataManager()
        {

        }

        private string GetOutputFilePath()
        {
            string currentPath = Path.Combine(Directory.GetCurrentDirectory(), "settings.json");

            return currentPath;
        }

        private void InitWithParamters()
        {
            ProjectPath = System.IO.Path.GetDirectoryName(Application.StartupPath);
            TileWidth = 16;
            TileHeight = 16;
            MapWidth = 17;
            MapHeight = 13;
            CurrentLayer = 1;
            Layer1 = new List<int>();
            for (var y = 0; y < MapHeight; y++)
            {
                for(var x = 0; x < MapWidth; x++)
                {
                    Layer1.Add(0);
                }
            }
            TilesetImage = "";
        }

        public void Import()
        {
            string path = GetOutputFilePath();

            // 파일이 없으면 매개변수를 생성하고 함수를 빠져나갑니다.
            if(!File.Exists(path))
            {
                InitWithParamters();
                return;
            }

            try
            {
                string contents = File.ReadAllText(path, Encoding.UTF8);
                MapFile option = JsonConvert.DeserializeObject<MapFile>(contents);

                ProjectPath = option.ProjectPath;
                TileWidth = option.TileWidth;
                TileHeight = option.TileHeight;
                MapWidth = option.MapWidth;
                MapHeight = option.MapHeight;
                CurrentLayer = option.CurrentLayer;
                Layer1 = option.Layer1;

                TilesetImage = option.TilesetImage;

            } catch(Exception ex) {

            }

        }

        public void Save()
        {
            MapFile option = new MapFile()
            {
                ProjectPath = ProjectPath,
                TileWidth = TileWidth,
                TileHeight = TileHeight,
                MapWidth = MapWidth,
                MapHeight = MapHeight,
                CurrentLayer = CurrentLayer,
                Layer1 = Layer1,
                TilesetImage = TilesetImage,
            };

            // 문자열로 변환합니다.
            string contents = JsonConvert.SerializeObject(option, Formatting.Indented);

            File.WriteAllText(GetOutputFilePath(), contents);
        }

    }
}
