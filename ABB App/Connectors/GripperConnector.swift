//
//  GripperConnector.swift
//  ABB App
//
//  Created by Artem Malkarov on 24.10.2025.
//

import Foundation
import Network
import IndustrialKit

nonisolated class GripperConnector: ToolConnector, @unchecked Sendable
{
    // MARK: - Connection
    override var parameters: [ConnectionParameter]
    {
        [
            .init(name: "IP Address", value: "169.254.5.175"),
            .init(name: "Port", value: "5001")
        ]
    }
    
    override func connection_process() async -> Bool
    {
        // Check if connection parameters are provided
        guard parameters.count > 0 else
        {
            await MainActor.run
            {
                self.output += "\n<failed: ❌ missing connection address>"
            }
            return false
        }
        
        // Extract host and port
        let host = parameters[0].value as! String
        let port: NWEndpoint.Port =
        {
            if parameters.count > 1, let p = UInt16(parameters[1].value as! String)
            {
                return NWEndpoint.Port(rawValue: p) ?? 5001
            }
            else
            {
                return 5001
            }
        }()
        
        // Reset all connection state before attempting new connection
        await MainActor.run
        {
            SocketHolder.nw_connection?.cancel()
            SocketHolder.nw_connection = nil
            SocketHolder.is_ready = false
        }
        
        // Create new TCP connection
        let new_connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        SocketHolder.nw_connection = new_connection
        
        output += "\n"
        
        // State handler: updates output and connection state safely on MainActor
        @Sendable func handleState(_ state: NWConnection.State) async
        {
            await MainActor.run
            {
                switch state
                {
                case .ready:
                    self.output += "<done: ✅ connection ready>"
                    SocketHolder.is_ready = true
                    
                case .failed(let error):
                    self.output += "<failed: ❌ connection failed: \(error)>"
                    SocketHolder.nw_connection?.cancel()
                    SocketHolder.nw_connection = nil
                    SocketHolder.is_ready = false
                    
                case .waiting(let error):
                    self.output += "<failed: ⚠️ connection waiting: \(error)>"
                    SocketHolder.nw_connection?.cancel()
                    SocketHolder.nw_connection = nil
                    SocketHolder.is_ready = false
                    
                default:
                    break
                }
            }
        }
        
        // Assign the state update handler
        new_connection.stateUpdateHandler = { state in
            Task
            {
                await handleState(state)
            }
        }
        
        // Start the connection
        new_connection.start(queue: SocketHolder.nw_queue)
        
        // Timeout handling: wait max 1 second
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        if !SocketHolder.is_ready
        {
            await MainActor.run
            {
                self.output += "<failed: ❌ connection timeout>"
                SocketHolder.nw_connection?.cancel()
                SocketHolder.nw_connection = nil
                SocketHolder.is_ready = false
            }
        }
        
        // Return final connection status
        return SocketHolder.is_ready
    }
    
    override func disconnection_process()
    {
        guard let active_connection = SocketHolder.nw_connection else
        {
            self.output += "ℹ️ no active connection"
            return
        }
        
        active_connection.cancel()
        SocketHolder.nw_connection = nil
        SocketHolder.is_ready = false
    }
    
    // Holder for connection instance and state
    private struct SocketHolder
    {
        static var nw_connection: NWConnection? = nil
        static var is_ready = false
        static let nw_queue = DispatchQueue(label: "tool_socket_queue")
    }
    
    // MARK: - Performing
    override func perform(code: Int)
    {
        // Format command string
        let command_str = "SET_TOGGLE \(code)"
        
        guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
        {
            print("❌ connection not ready")
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        processing = true
        
        active_connection.send(
            content: command_str.data(using: .utf8),
            completion: .contentProcessed
            { send_error in /*.idempotent*/
                semaphore.signal()
            }
        )
        
        semaphore.wait()
        usleep(500000)
        
        func receive_next()
        {
            self.get_output
            { output in
                if !(output?.state.processing ?? true)
                {
                    print("✅ received TOGGLE_OK, done waiting")
                    semaphore.signal()
                    return
                }
                else
                {
                    if self.connected
                    {
                        receive_next()
                    }
                    else
                    {
                        semaphore.signal()
                    }
                }
            }
        }
        
        if connected
        {
            receive_next()
        }
        else
        {
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    // MARK: - Statistics
    override func initial_charts_data() -> [WorkspaceObjectChart]
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [WorkspaceObjectChart]()@*/return [WorkspaceObjectChart]()/*@END_MENU_TOKEN@*/
    }
    
    override func updated_charts_data() -> [WorkspaceObjectChart]?
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [WorkspaceObjectChart]()@*/return [WorkspaceObjectChart]()/*@END_MENU_TOKEN@*/
    }
    
    override func initial_states_data() -> [StateItem]
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [StateItem]()@*/return [StateItem]()/*@END_MENU_TOKEN@*/
    }
    
    override func updated_states_data() -> [StateItem]?
    {
        /*@START_MENU_TOKEN@*//*@PLACEHOLDER=return [StateItem]()@*/return [StateItem]()/*@END_MENU_TOKEN@*/
    }
    
    var processing = false
    var completed  = false
    var error = false
    
    var is_opened = false
    
    // MARK: - Other
    public func get_output(completion: @escaping ((is_opened: Bool, state: (processing: Bool, completed: Bool, error: Bool))?) -> Void)
    {
        usleep(50000)
        
        guard let active_connection = SocketHolder.nw_connection, SocketHolder.is_ready else
        {
            print("❌ connection not ready")
            completion(nil)
            return
        }
        
        // Send GET_OUTPUT command
        let command_str = "GET_OUTPUT"
        active_connection.send(content: command_str.data(using: .utf8), completion: .contentProcessed { send_error in
            if let send_error = send_error
            {
                print("\(send_error)")
                completion(nil)
                return
            }
            
            // Receive response
            active_connection.receive(minimumIncompleteLength: 1, maximumLength: 256)
            { data, _, _, recv_error in
                guard let data = data,
                      let response_text = String(data: data, encoding: .utf8),
                      recv_error == nil else
                {
                    print("❌ receive error or no data")
                    completion(nil)
                    return
                }
                
                //print("📍 robot output: \(response_text)")
                
                // Parse response
                let parsed_values = response_text.split(separator: ",").compactMap { Float($0) }
                if parsed_values.count == 4
                {
                    // Update state
                    self.is_opened = (parsed_values[0] == 1)
                    self.processing = (parsed_values[1] == 1)
                    self.completed = (parsed_values[2] == 1)
                    self.error = (parsed_values[3] == 1)
                }
                else
                {
                    print("⚠️ response parsing failed (expected 4 values, got \(response_text.count))")
                }
            }
            
            completion((
                is_opened: self.is_opened,
                state: (processing: self.processing, completed: self.completed, error: self.error)
            ))
        })
    }
}
