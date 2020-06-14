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
        public int[] Tilemap { get; set; }
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
            Tilemap = new int[256];
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
                Dictionary<string, string> option = JsonConvert.DeserializeObject<Dictionary<string, string>>(contents);

                ProjectPath = option["ProjectPath"];
                TileWidth = int.Parse(option["TileWidth"]);
                TileHeight = int.Parse(option["TileHeight"]);
                MapWidth = int.Parse(option["MapWidth"]);
                MapHeight = int.Parse(option["MapHeight"]);
                CurrentLayer = int.Parse(option["CurrentLayer"]);
                Tilemap = JsonConvert.DeserializeObject<List<int>>(option["Tilemap"]).ToArray();

                TilesetImage = option["TilesetImage"];

            } catch(Exception ex) {

            }



        }

        public void Save()
        {
            
            Dictionary<string, string> option = new Dictionary<string, string>();

            // 매개변수를 JSON Key/Value로 변환합니다.
            option["ProjectPath"] = ProjectPath;
            option["TileWidth"] = TileWidth.ToString();
            option["TileHeight"] = TileHeight.ToString();
            option["MapWidth"] = MapWidth.ToString();
            option["MapHeight"] = MapHeight.ToString();
            option["CurrentLayer"] = CurrentLayer.ToString();

            // 리스트를 JSON 문자열로 변환합니다.
            var list = new List<int>();
            list.AddRange(Tilemap);
            option["Tilemap"] = JsonConvert.SerializeObject(list);

            option["TilesetImage"] = TilesetImage.ToString();

            // 문자열로 변환합니다.
            string contents = JsonConvert.SerializeObject(option, Formatting.Indented);

            File.WriteAllText(GetOutputFilePath(), contents);
        }

    }
}
