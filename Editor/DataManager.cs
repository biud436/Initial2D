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
        public int StartMapId { get; set; }
        public int CurrentMapId { get; set; }
        public string TilesetImage { get; set; }

        public Map CurerntMap { get; set; }

        public List<int> Layer1 { get; set; }

        private DataManager()
        {

        }

        private string GetOutputMapFilePath(string filename)
        {
            string editorRoot = DataManager.Instance.ProjectPath;
            string mainRoot = "";

            if (String.IsNullOrEmpty(editorRoot))
            {
                editorRoot = Directory.GetCurrentDirectory();
            }

            if (File.Exists(Path.Combine(editorRoot, "Editor.exe")))
            {
                mainRoot = Directory.GetParent(editorRoot).Parent.FullName;
            }
            else
            {
                mainRoot = editorRoot;
            }

            string currentPath = Path.Combine(mainRoot, "resources", "maps", filename);

            return currentPath;
        }

        private string GetMainRootPath()
        {
            string editorRoot = DataManager.Instance.ProjectPath;
            string mainRoot = "";

            if (String.IsNullOrEmpty(editorRoot))
            {
                editorRoot = Directory.GetCurrentDirectory();
            }

            if (File.Exists(Path.Combine(editorRoot, "Editor.exe")))
            {
                mainRoot = Directory.GetParent(editorRoot).Parent.FullName;
            }
            else
            {
                mainRoot = editorRoot;
            }

            if(String.IsNullOrEmpty(mainRoot))
            {
                mainRoot = Directory.GetCurrentDirectory();
            }

            return mainRoot;
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
            StartMapId = 1;
            CurrentMapId = 1;

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

        public void ImportMapFiles()
        {
            // 맵 파일을 로드합니다.
            var filename = GetOutputMapFilePath(String.Format("map{0}.json", CurrentMapId));

            // 맵 파일이 없으면 처음부터 생성합니다.
            if (!File.Exists(filename))
            {
                Layer1 = new List<int>();
                for (var y = 0; y < MapHeight; y++)
                {
                    for (var x = 0; x < MapWidth; x++)
                    {
                        Layer1.Add(0);
                    }
                }
                return;
            }

            string contents = File.ReadAllText(filename);
            
            Map mapFile = JsonConvert.DeserializeObject<Map>(contents);
            CurrentMapId = mapFile.Id;
            Layer1 = mapFile.Layer1;
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
                ProjectConfigFile option = JsonConvert.DeserializeObject<ProjectConfigFile>(contents);

                ProjectPath = option.ProjectPath;
                TileWidth = option.TileWidth;
                TileHeight = option.TileHeight;
                MapWidth = option.MapWidth;
                MapHeight = option.MapHeight;
                CurrentLayer = option.CurrentLayer;
                StartMapId = option.StartMapId;
                CurrentMapId = option.CurrentMapId;
                TilesetImage = option.TilesetImage;

                ImportMapFiles();

            } catch(Exception ex) {

            }

        }

        public void SaveMapFiles()
        {
            // 맵 파일을 저장합니다.
            Map mapFile = new Map
            {
                Name = "None",
                Id = CurrentMapId,
                Layer1 = Layer1,
            };

            string contents = JsonConvert.SerializeObject(mapFile, Formatting.Indented);
            File.WriteAllText(GetOutputMapFilePath("map1.json"), contents);
        }

        public void Save()
        {
            ProjectConfigFile option = new ProjectConfigFile()
            {
                ProjectPath = ProjectPath,
                TileWidth = TileWidth,
                TileHeight = TileHeight,
                MapWidth = MapWidth,
                MapHeight = MapHeight,
                CurrentLayer = CurrentLayer,
                StartMapId = StartMapId,
                CurrentMapId = CurrentMapId,
                TilesetImage = TilesetImage,
            };

            // 프로젝트 파일을 저장합니다.
            string contents = JsonConvert.SerializeObject(option, Formatting.Indented);
            File.WriteAllText(GetOutputFilePath(), contents);
            File.WriteAllText(Path.Combine(GetMainRootPath(), "settings.json"), contents);

            SaveMapFiles();

        }

    }
}
