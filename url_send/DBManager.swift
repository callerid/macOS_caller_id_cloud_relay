class DBManager: NSObject {
    
    // ------------------------------------------------------------
    // Setup database class for connecting/editing/closing database
    // ------------------------------------------------------------
    static let shared: DBManager = DBManager()
    
    // Setup field constants for accessing fields in database
    let field_datetime = "DateTime"
    let field_line = "Line"
    let field_type = "Type"
    let field_indicator = "Indicator"
    let field_duration = "Duration"
    let field_checksum = "Checksum"
    let field_rings = "Rings"
    let field_number = "Number"
    let field_name = "Name"
    
    
    // Needed database variables
    let databaseFileName = "database.sqlite"
    var pathToDatabase: String!
    var database: FMDatabase!
    
    // Initalize location of database
    override init() {
        
        super.init()
        
        let documentsDirectory = (NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString) as String
        pathToDatabase = documentsDirectory.appending("/\(databaseFileName)")
        
    }
    
    // ----------------------------------------------------------
    //                    Database functions
    // ----------------------------------------------------------
    // Create the database
    func createDatabase() -> Bool {
        var created = false
        
        if !FileManager.default.fileExists(atPath: pathToDatabase) {
            database = FMDatabase(path: pathToDatabase!)
            
            if database != nil {
                // Open the database.
                if database.open() {
                    
                    // Create tables with needed formats
                    let creationQuery =
                        "CREATE TABLE calls (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL," +
                            "DateTime TEXT," +
                            "Line TEXT," +
                            "Type TEXT," +
                            "Indicator TEXT," +
                            "Duration TEXT," +
                            "Checksum TEXT," +
                            "Rings TEXT," +
                            "Number TEXT," +
                            "Name TEXT" +
                            ");"
                    
                    database.executeStatements(creationQuery)
                    created = true
                    
                    // At the end close the database.
                    database.close()
                }
                else {
                    print("Could not open the database.")
                }
            }
        }
        
        return created
    }
    
    // ----------------------------------------------------------
    //                       Open Database
    // ----------------------------------------------------------
    
    func openDatabase() -> Bool {
        if database == nil {
            if FileManager.default.fileExists(atPath: pathToDatabase) {
                database = FMDatabase(path: pathToDatabase)
            }
        }
        
        if database != nil {
            if database.open() {
                return true
            }
        }
        
        return false
    }
    
    // ----------------------------------------------------------
    //                     Execute a sql query
    // ----------------------------------------------------------
    
    func executeQuery(query: String) -> Bool {
        
        if(openDatabase()){
            
            if !database.executeStatements(query) {
                print("Query Failed: " + query)
                let errorString = (database.lastError(), database.lastErrorMessage())
                print(errorString)
                return false
            }
            
            database.close()
            return true
        }
        
        return false
        
    }
    
    // ----------------------------------------------------------
    //                 Get resultset from query
    // ----------------------------------------------------------
    
    func getResults(query: String, values: [String]) -> FMResultSet {
        
        if(openDatabase()){
            do {
                let results = try database.executeQuery(query, values: values)
                return results
            } catch {
                print("Get resultset failed.")
            }
        }
        
        return FMResultSet()
        
    }
    
    // ----------------------------------------------------------
    //                 Query Executioins
    // ----------------------------------------------------------
    func addToLog(dateTime:String,
                  line:String,
                  type:String,
                  indicator:String,
                  dur:String,
                  checksum:String,
                  rings:String,
                  num:String,
                  name:String){
        
        let insertQuery = "INSERT INTO calls (" +
        "\(field_datetime)" +
        "\(field_line)" +
        "\(field_type)" +
        "\(field_indicator)" +
        "\(field_duration)" +
        "\(field_checksum)" +
        "\(field_rings)" +
        "\(field_number)" +
        "\(field_name) " +
        ") VALUES (" +
        "'\(dateTime)'," +
        "'\(line)'," +
        "'\(type)'," +
        "'\(indicator)'," +
        "'\(dur)'," +
        "'\(checksum)'," +
        "'\(rings)'," +
        "'\(num)'," +
        "'\(name)'" +
        ")"
        
        if(executeQuery(query: insertQuery)){
            print("Inserted to log.")
        }
        else{
            print("Failed to insert to log.")
        }
        
    }
    
}
