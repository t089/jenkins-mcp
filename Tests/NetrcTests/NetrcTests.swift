import Testing
@testable import Netrc
import Foundation

@Suite("Netrc Parser Tests")
struct NetrcTests {
    
    @Test("Parse empty file")
    func parseEmptyFile() throws {
        let parser = NetrcParser()
        let netrc = try parser.parse("")
        #expect(netrc.machines.count == 0)
    }
    
    @Test("Parse basic entry")
    func parseBasicEntry() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com login myuser password mypass
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "myuser")
        #expect(netrc.machines[0].password == "mypass")
        #expect(netrc.machines[0].account == nil)
        #expect(netrc.machines[0].port == nil)
    }
    
    @Test("Parse multiple machines")
    func parseMultipleMachines() throws {
        let parser = NetrcParser()
        let content = """
        machine host1.com login user1 password pass1
        machine host2.com login user2 password pass2 account acct2
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 2)
        
        #expect(netrc.machines[0].name == "host1.com")
        #expect(netrc.machines[0].login == "user1")
        #expect(netrc.machines[0].password == "pass1")
        
        #expect(netrc.machines[1].name == "host2.com")
        #expect(netrc.machines[1].login == "user2")
        #expect(netrc.machines[1].password == "pass2")
        #expect(netrc.machines[1].account == "acct2")
    }
    
    @Test("Parse with port")
    func parseWithPort() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com port 8080 login user password pass
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].port == 8080)
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
    }
    
    @Test("Parse default entry")
    func parseDefault() throws {
        let parser = NetrcParser()
        let content = """
        machine specific.com login specificuser password specificpass
        default login defaultuser password defaultpass
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 2)
        
        // Default should be merged into specific machine
        #expect(netrc.machines[0].name == "specific.com")
        #expect(netrc.machines[0].login == "specificuser")
        #expect(netrc.machines[0].password == "specificpass")
        
        #expect(netrc.machines[1].name == nil) // default has nil name
        #expect(netrc.machines[1].login == "defaultuser")
        #expect(netrc.machines[1].password == "defaultpass")
    }
    
    @Test("Parse default merging")
    func parseDefaultMerging() throws {
        let parser = NetrcParser()
        let content = """
        default login defaultuser password defaultpass account defaultacct
        machine partial.com password onlypass
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 2)
        
        // The machine should inherit missing values from default
        let partialMachine = netrc.machines[1]
        #expect(partialMachine.name == "partial.com")
        #expect(partialMachine.login == "defaultuser") // inherited from default
        #expect(partialMachine.password == "onlypass") // overridden
        #expect(partialMachine.account == "defaultacct") // inherited from default
    }
    
    @Test("Parse with comments")
    func parseWithComments() throws {
        let parser = NetrcParser()
        let content = """
        # This is a comment
        machine example.com login user password pass # inline comment
        # Another comment
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
    }
    
    @Test("Parse with whitespace")
    func parseWithWhitespace() throws {
        let parser = NetrcParser()
        let content = """
        
        
        machine    example.com    login    user    password    pass    
        
        
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
    }
    
    @Test("Parse multiline format")
    func parseMultilineFormat() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com
        login user
        password pass
        account acct
        """
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
        #expect(netrc.machines[0].account == "acct")
    }
    
    @Test("Parse macdef")
    func parseMacdef() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com login user password pass
        macdef uploadfile
        cd /tmp
        put file.txt
        
        machine other.com login user2 password pass2
        """
        let netrc = try parser.parse(content)
        
        // macdef should be ignored, but parsing should continue
        #expect(netrc.machines.count == 2)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[1].name == "other.com")
    }
    
    @Test("Parse unknown keywords")
    func parseUnknownKeywords() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com
        login user
        unknownkey value
        password pass
        anotherkey
        """
        let netrc = try parser.parse(content)
        
        // Unknown keywords should be ignored
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
    }
    
    @Test("Parse Windows line endings")
    func parseWindowsLineEndings() throws {
        let parser = NetrcParser()
        let content = "machine example.com\r\nlogin user\r\npassword pass\r\n"
        let netrc = try parser.parse(content)
        
        #expect(netrc.machines.count == 1)
        #expect(netrc.machines[0].name == "example.com")
        #expect(netrc.machines[0].login == "user")
        #expect(netrc.machines[0].password == "pass")
    }
    
    @Test("Parse error: expected value")
    func parseErrorExpectedValue() throws {
        let parser = NetrcParser()
        let content = "machine"
        
        #expect(throws: NetrcError.expectedValue(after: "machine")) {
            try parser.parse(content)
        }
    }
    
    @Test("Parse error: invalid port")
    func parseErrorInvalidPort() throws {
        let parser = NetrcParser()
        let content = "machine example.com port notanumber"
        
        #expect(throws: NetrcError.expectedValue(after: "port")) {
            try parser.parse(content)
        }
    }
}

@Suite("Netrc Authorization Tests")
struct NetrcAuthorizationTests {
    
    @Test("Authorization for URL")
    func authorizationForURL() throws {
        let parser = NetrcParser()
        let content = """
        machine api.example.com login apiuser password apipass
        machine example.com login user password pass
        """
        let netrc = try parser.parse(content)
        
        // Test exact match
        let url1 = URL(string: "https://api.example.com/endpoint")!
        let auth1 = netrc.authorization(for: url1)
        #expect(auth1 != nil)
        #expect(auth1?.login == "apiuser")
        #expect(auth1?.password == "apipass")
        
        // Test different host
        let url2 = URL(string: "https://example.com/path")!
        let auth2 = netrc.authorization(for: url2)
        #expect(auth2 != nil)
        #expect(auth2?.login == "user")
        #expect(auth2?.password == "pass")
        
        // Test no match
        let url3 = URL(string: "https://other.com/")!
        let auth3 = netrc.authorization(for: url3)
        #expect(auth3 == nil)
    }
    
    @Test("Authorization with port")
    func authorizationWithPort() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com port 8080 login user8080 password pass8080
        machine example.com login user password pass
        """
        let netrc = try parser.parse(content)
        
        // Test URL with matching port
        let url1 = URL(string: "https://example.com:8080/api")!
        let auth1 = netrc.authorization(for: url1)
        #expect(auth1 != nil)
        #expect(auth1?.login == "user8080")
        #expect(auth1?.password == "pass8080")
        
        // Test URL without port (should match entry without port)
        let url2 = URL(string: "https://example.com/api")!
        let auth2 = netrc.authorization(for: url2)
        #expect(auth2 != nil)
        #expect(auth2?.login == "user")
        #expect(auth2?.password == "pass")
    }
    
    @Test("Authorization with default")
    func authorizationWithDefault() throws {
        let parser = NetrcParser()
        let content = """
        machine specific.com login specificuser password specificpass
        default login defaultuser password defaultpass
        """
        let netrc = try parser.parse(content)
        
        // Test specific match
        let url1 = URL(string: "https://specific.com/")!
        let auth1 = netrc.authorization(for: url1)
        #expect(auth1 != nil)
        #expect(auth1?.login == "specificuser")
        #expect(auth1?.password == "specificpass")
        
        // Test default fallback
        let url2 = URL(string: "https://unknown.com/")!
        let auth2 = netrc.authorization(for: url2)
        #expect(auth2 != nil)
        #expect(auth2?.login == "defaultuser")
        #expect(auth2?.password == "defaultpass")
    }
    
    @Test("Authorization missing credentials")
    func authorizationMissingCredentials() throws {
        let parser = NetrcParser()
        let content = """
        machine example.com login user
        machine other.com password pass
        """
        let netrc = try parser.parse(content)
        
        // Missing password
        let url1 = URL(string: "https://example.com/")!
        let auth1 = netrc.authorization(for: url1)
        #expect(auth1 == nil)
        
        // Missing login
        let url2 = URL(string: "https://other.com/")!
        let auth2 = netrc.authorization(for: url2)
        #expect(auth2 == nil)
    }
}