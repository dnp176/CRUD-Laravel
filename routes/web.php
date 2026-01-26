<?php

use Illuminate\Support\Facades\Route;

use App\Http\Controllers\TodoController;

Route::get('/', [TodoController::class, 'index']);
Route::post('/todo', [TodoController::class, 'store'])->name('todo.store');
Route::delete('/todo/{id}', [TodoController::class, 'destroy'])->name('todo.destroy');
