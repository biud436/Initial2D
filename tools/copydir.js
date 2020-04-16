/**
 * @author Jinseok Eo(biud436)
 * @description
 * copydir {0} {1} --dir
 * copydir {0} {1} --file
 */
const fs = require('fs-extra');
const path = require('path');
const args = process.argv.slice(2);
const argv = require("minimist")(args);

const sourceDir = argv._[0];
const targetDir = argv._[1];
const type = argv.file || argv.dir;

class UtilsImpl {
    constructor() {
        if(argv.file) {
            this.copyFile();
        } else if(argv.dir) {
            this.copyDir();
        }
    }

    copyDir() {

        if(fs.existsSync(targetDir) && fs.lstatSync(targetDir).isDirectory()) {
            fs.removeSync(targetDir);
        }

        fs.copySync(sourceDir, targetDir, {overwrite:true, errorOnExist:false, recursive:true, filter: (src, dst) => {
            if(!fs.existsSync(src)) {
                console.warn(`There is no file called ${src}`);
                return false;
            }
            console.log("copy %s %s ", src, dst);
            return true;
        }});        

        process.exit(0);
    }

    copyFile() {

        fs.copySync(sourceDir, targetDir, {overwrite:true, errorOnExist:false, recursive:true, filter: (src, dst) => {
            if(!fs.existsSync(src)) {
                console.warn(`There is no file called ${src}`);
                return false;
            } 
            console.log("copy %s %s ", src, dst);
            return true;
        }});      

        process.exit(0);
    }
}

let utils = new UtilsImpl();

