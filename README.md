
# react-native-spatialite

React Native Spatialite Plugin for iOS

## Installation

Just add to `package.json`:

`
"dependencies": {
    "react-native-spatialite": "git://github.com/NeliHarbuzava/react-native-spatialite.git"
  }
`

## Linking

1. In XCode, in the project navigator, right click Libraries ➜ Add Files to "<project_name>"
2. Go to node_modules ➜ react-native-spatialite and add RNSpatialite.xcodeproj
3. In XCode, "<project_name>" ➜ Build Phases ➜ Link Binary With Libraries ➜ add libRNSpatialite.a
4. You have to go to your project's file, select Build Settings and search for 'Header Search Paths'.
There you should include the path "$(SRCROOT)/../node_modules/react-native-spatialite/ios" (non-recursive option)
5. Set project's "Enable bitcode" in the Build Settings to 'No'
6. Run your project

## Usage
```javascript
import db from 'react-native-spatialite';

db.createConnection('test.db').then(connected => {
    console.log('Database is connected', connected);
    return db.getVersion();
}).then(
    array => {
        console.log({arr});
        return db.executeQuery('SELECT * FROM MyTable');
    }
).then(
    rows => {
        console.log({rows});
    }
).catch(
    err => {
        throw err;
    }
);
```
  
