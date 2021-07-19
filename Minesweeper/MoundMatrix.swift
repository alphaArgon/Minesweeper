import Foundation

protocol MoundMatrixDelegate {
    func moundMatrix(_ moundMatrix: MoundMatrix, moundAt index: MoundMatrix.Index) -> Mound
    func moundMatrix(_ moundMatrix: MoundMatrix, update mound: Mound, at index: MoundMatrix.Index)
    func moundMatrix(_ moundMatrix: MoundMatrix, didRemove mound: Mound)
}

struct MoundMatrix {
    struct Index: Equatable, Hashable {
        var column: Int
        var row: Int
        
        init(_ column: Int, _ row: Int) {
            self.column = column
            self.row = row
        }
        
        var vicinities: Set<Index> {Set(arrayLiteral:
            Index(column - 1,   row - 1),
            Index(column,       row - 1),
            Index(column + 1,   row - 1),
            Index(column - 1,   row    ),
            Index(column,       row    ),
            Index(column + 1,   row    ),
            Index(column - 1,   row + 1),
            Index(column,       row + 1),
            Index(column + 1,   row + 1)
        )}
    }
    
    var numberOfColumns: Int
    var numberOfRows: Int
    var delegate: MoundMatrixDelegate
    
    private var array: [Mound] = []
    
    init(numberOfColumns: Int, numberOfRows: Int, delegate: MoundMatrixDelegate) {
        self.numberOfColumns = numberOfColumns
        self.numberOfRows = numberOfRows
        self.delegate = delegate
        
        for row in 0..<numberOfRows {for column in 0..<numberOfColumns {
            array.append(delegate.moundMatrix(self, moundAt: Index(column, row)))
        }}
    }
    
    subscript(_ index: Index) -> Mound? {
        guard contains(index: index) else {return nil}
        return array[index.row * numberOfColumns + index.column]
    }
    
    private func index(rawIndex: Int) -> Index {Index(rawIndex % numberOfColumns, rawIndex / numberOfColumns)}
    
    func contains(index: Index) -> Bool {
        return index.column >= 0 && index.column < numberOfColumns && index.row >= 0 && index.row < numberOfRows
    }
    
    func forEach(body callback: (Mound) throws -> Void) rethrows {
        try array.forEach(callback)
    }
    
    func forEach(body callback: (Mound, Index) throws -> Void) rethrows {
        for rawIndex in 0..<array.count {
            try callback(array[rawIndex], index(rawIndex: rawIndex))
        }
    }
    
    func forEach(body callback: (Mound, Index, Int) throws -> Void) rethrows {
        for rawIndex in 0..<array.count {
            try callback(array[rawIndex], index(rawIndex: rawIndex), rawIndex)
        }
    }
    
    func indexOf(_ mound: Mound) -> Index? {
        guard let rawIndex = (array.firstIndex {$0 == mound}) else {return nil}
        return index(rawIndex: rawIndex)
    }
    
    mutating func setSize(numberOfColumns: Int, numberOfRows: Int) {
        self.numberOfColumns = numberOfColumns
        self.numberOfRows = numberOfRows
        
        let newCount = numberOfColumns * numberOfRows
        
        for rawIndex in 0..<min(array.count, newCount) {
            delegate.moundMatrix(self, update: array[rawIndex], at: index(rawIndex: rawIndex))
        }
        
        var rawIndex = array.count
        while rawIndex < newCount {
            array.append(delegate.moundMatrix(self, moundAt: index(rawIndex: rawIndex)))
            rawIndex += 1
        }
        while rawIndex > newCount {
            delegate.moundMatrix(self, didRemove: array.removeLast())
            rawIndex -= 1
        }
    }
}
