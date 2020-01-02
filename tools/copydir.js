const fs = require('fs-extra');
const path = require('path');
const args = process.argv.slice(2);

/**
 * copydir {0} {1} dir
 * copydir {0} {1} file
 */
const sourceDir = args[0];
const targetDir = args[1];
const type = args[2];

class UtilsImpl {
    constructor() {

        switch(type) {
            default:
            case "dir":
                this.copyDir();
                break;
            case "file":
                this.copyFile();
                break;
        }
        
    }

    copyDir() {

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

