using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Collections;
using System.IO;
using Newtonsoft.Json;
using System.Reflection;
using Editor.Loader;

namespace Editor
{
    public sealed class DataManager
    {
        private static volatile DataManager instance;
        private static object syncRoot = new Object();

        /// <summary>
        /// Checks whether a config file has to be created newly.
        /// </summary>
        public Version VERSION = new Version("0.0.1");

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
                            instance = new DataManager()
                            {
                                MapWidth = 17,
                                MapHeight = 13,
                            };
                            instance.Import();
                        }
                    }
                }

                return instance;
            }
        }

        public string ProjectPath {
            get
            {
                return mProjectConfigFile.ProjectPath;
            }
            
            set
            {
                mProjectConfigFile.ProjectPath = value;
            }
        }
        public int TileWidth 
        {
            get
            {
                return mProjectConfigFile.TileWidth;
            }
            
            set
            {
                mProjectConfigFile.TileWidth = value;
            }
        }
        public int TileHeight
        {
            get
            {
                return mProjectConfigFile.TileHeight;
            }

            set
            {
                mProjectConfigFile.TileHeight = value;
            }
        }
        public int MapWidth { get; set; }
        public int MapHeight { get; set; }
        public int CurrentLayer
        {
            get
            {
                return mProjectConfigFile.CurrentLayer;
            }

            set
            {
                mProjectConfigFile.CurrentLayer = value;
            }
        }
        public int StartMapId
        {
            get
            {
                return mProjectConfigFile.StartMapId;
            }

            set
            {
                mProjectConfigFile.StartMapId = value;
            }
        }
        public int CurrentMapId
        {
            get
            {
                return mProjectConfigFile.CurrentMapId;
            }

            set
            {
                mProjectConfigFile.CurrentMapId = value;
            }
        }
        public string TilesetImage { get; set; }
        public int WindowWidth
        {
            get
            {
                return mProjectConfigFile.WindowWidth;
            }

            set
            {
                mProjectConfigFile.WindowWidth = value;
            }
        }
        public int WindowHeight
        {
            get
            {
                return mProjectConfigFile.WindowHeight;
            }

            set
            {
                mProjectConfigFile.WindowHeight = value;
            }
        }

        public List<int> Layer1 { get; set; }


        private ProjectConfigFile mProjectConfigFile;
        private Map mCurrentMap;

        private DataManager()
        {

        }

        private void InitWithParameters()
        {

        }

        public void Import()
        {
            // 시작 폴더를 지정합니다.
            string currentPath = Path.GetDirectoryName(Application.StartupPath);
            string configFilePath = Path.Combine(currentPath, "config.json");

            if(!File.Exists(configFilePath))
            {
                // 설정 파일이 없으면 새로 만듭니다.
                mProjectConfigFile = new ProjectConfigFile();
                string contents = JsonConvert.SerializeObject(mProjectConfigFile);
                File.WriteAllText(configFilePath, contents);
            } else
            {
                // 프로젝트 설정 파일을 불러옵니다.
                string contents = File.ReadAllText(configFilePath);
                mProjectConfigFile = JsonConvert.DeserializeObject<ProjectConfigFile>(contents);
            }

            // 맵 파일을 불러옵니다
            if(MapLoader.Instance.Exist(StartMapId))
            {
                // 맵 파일이 존재하면 불러옵니다.
                mCurrentMap = MapLoader.Instance.Load(StartMapId);
            } else
            {
                // 시작 맵 파일이 존재하지 않으면 새로 만듭니다.
                mCurrentMap = MapLoader.Instance.CreateEmptyMap(MapWidth, MapHeight, StartMapId);
            }
            
        }

        public void SaveMapFiles()
        {

        }

        public void Save()
        {

        }

    }
}
