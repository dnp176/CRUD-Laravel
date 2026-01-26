<?php
namespace App\Http\Controllers;
use Illuminate\Http\Request;
use App\Models\Todo;

class TodoController extends Controller
{
    public function index() {
        return view('welcome', ['todos' => Todo::all()]);
    }

    public function store(Request $request) {
        $request->validate(['task' => 'required']);
        Todo::create(['task' => $request->task]);
        return back();
    }

    public function destroy($id) {
        Todo::destroy($id);
        return back();
    }
}
