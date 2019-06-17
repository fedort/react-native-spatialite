
# react-native-spatialite

React Native Spatialite Plugin for iOS

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
  
